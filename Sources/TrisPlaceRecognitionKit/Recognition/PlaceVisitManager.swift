//
//  PlaceVisitManager.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Combine
import Foundation

@MainActor
public final class PlaceVisitManager: ObservableObject {

    @Published
    public private(set) var recognizedPlaces: [RecognizedPlace] = []

    @Published
    public private(set) var activeVisits: [PlaceVisitRecord] = []

    @Published
    public private(set) var isMonitoring = false

    @Published
    public private(set) var lastErrorMessage: String?

    @Published
    public private(set) var lastVisitErrorMessage: String?

    private let monitor: PlaceRecognitionMonitor

    private let coordinator: PlaceVisitCoordinator

    private let visitStore: any PlaceVisitStoring

    private var restorationTask:
        Task<[PlaceVisitRecord], Error>?

    private var hasRestoredVisits = false

    public init(
        recognitionService: PlaceRecognitionService,
        visitStore: any PlaceVisitStoring,
        recognitionPolicy: PlaceRecognitionPolicy = .gpsConstrained,
        visitPolicy: PlaceVisitPolicy = .init(),
        refreshInterval: TimeInterval = 15
    ) {

        let coordinator = PlaceVisitCoordinator(
            store: visitStore,
            policy: visitPolicy
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: recognitionService,
            policy: recognitionPolicy,
            refreshInterval: refreshInterval
        )

        self.visitStore = visitStore
        self.coordinator = coordinator
        self.monitor = monitor

        bindMonitor()

        monitor.onSuccessfulRecognition = {
            [weak self] places, observedAt in

            guard let self else {
                return
            }

            try await self.processSuccessfulObservation(
                places,
                at: observedAt
            )
        }
    }

    @available(iOS 17.0, *)
    public convenience init(
        recognitionService: PlaceRecognitionService,
        recognitionPolicy: PlaceRecognitionPolicy = .gpsConstrained,
        visitPolicy: PlaceVisitPolicy = .init(),
        refreshInterval: TimeInterval = 15
    ) throws {

        let visitStore = try SwiftDataPlaceVisitStore()

        self.init(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: recognitionPolicy,
            visitPolicy: visitPolicy,
            refreshInterval: refreshInterval
        )
    }

    // MARK: - Monitoring

    @discardableResult
    public func restore() async throws -> [PlaceVisitRecord] {

        try await restoreIfNeeded()

        return activeVisits
    }

    public func start() async throws {

        try await restoreIfNeeded()

        await monitor.start()
    }

    public func refresh() async throws {

        try await restoreIfNeeded()

        await monitor.refresh()
    }

    public func stop() {

        monitor.stop()
    }

    // MARK: - Visit Queries

    /// Returns every persisted visit in chronological order.
    public func fetchVisits() async throws -> [PlaceVisitRecord] {

        let visits = try await visitStore.fetchAll()

        return sortedVisits(
            visits
        )
    }

    /// Returns every persisted visit for the specified place.
    public func fetchVisits(
        for placeID: UUID
    ) async throws -> [PlaceVisitRecord] {

        let visits = try await visitStore.fetchAll()

        return sortedVisits(
            visits.filter {
                $0.placeID == placeID
            }
        )
    }

    /// Returns visits that overlap the specified date range.
    ///
    /// A visit is included when any portion of the visit
    /// intersects the closed interval:
    ///
    /// startDate ... endDate
    ///
    /// Active visits are treated as continuing indefinitely.
    public func fetchVisits(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PlaceVisitRecord] {

        try validateDateRange(
            from: startDate,
            to: endDate
        )

        let visits = try await visitStore.fetchAll()

        return sortedVisits(
            visits.filter {
                overlaps(
                    $0,
                    startDate: startDate,
                    endDate: endDate
                )
            }
        )
    }

    /// Returns visits for one place that overlap
    /// the specified date range.
    public func fetchVisits(
        for placeID: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PlaceVisitRecord] {

        try validateDateRange(
            from: startDate,
            to: endDate
        )

        let visits = try await visitStore.fetchAll()

        return sortedVisits(
            visits.filter {
                $0.placeID == placeID
                    && overlaps(
                        $0,
                        startDate: startDate,
                        endDate: endDate
                    )
            }
        )
    }

    /// Returns the most recently started visit
    /// for the specified place.
    public func fetchLatestVisit(
        for placeID: UUID
    ) async throws -> PlaceVisitRecord? {

        let visits = try await visitStore.fetchAll()

        return visits
            .filter {
                $0.placeID == placeID
            }
            .max { lhs, rhs in

                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }

                return lhs.id.uuidString
                    < rhs.id.uuidString
            }
    }

    /// Returns all persisted visit events
    /// in chronological order.
    public func fetchEvents() async throws -> [PlaceVisitEvent] {

        let events = try await visitStore.fetchEvents()

        return events.sorted { lhs, rhs in

            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt < rhs.occurredAt
            }

            return lhs.id.uuidString
                < rhs.id.uuidString
        }
    }
}

private extension PlaceVisitManager {

    func bindMonitor() {

        monitor.$recognizedPlaces
            .assign(
                to: &$recognizedPlaces
            )

        monitor.$isMonitoring
            .assign(
                to: &$isMonitoring
            )

        monitor.$lastErrorMessage
            .assign(
                to: &$lastErrorMessage
            )

        monitor.$lastVisitErrorMessage
            .assign(
                to: &$lastVisitErrorMessage
            )
    }

    func restoreIfNeeded() async throws {

        if hasRestoredVisits {
            return
        }

        if let restorationTask {

            let restored = try await restorationTask.value

            activeVisits = restored
            hasRestoredVisits = true

            return
        }

        let coordinator = self.coordinator

        let task = Task {
            try await coordinator.restore()
        }

        restorationTask = task

        do {

            let restored = try await task.value

            activeVisits = restored
            hasRestoredVisits = true
            restorationTask = nil

        } catch {

            restorationTask = nil

            throw error
        }
    }

    func processSuccessfulObservation(
        _ places: [RecognizedPlace],
        at timestamp: Date
    ) async throws {

        _ = try await coordinator
            .processSuccessfulObservation(
                places,
                at: timestamp
            )

        activeVisits = try await coordinator.activeVisits()
    }

    func validateDateRange(
        from startDate: Date,
        to endDate: Date
    ) throws {

        guard startDate.timeIntervalSince1970.isFinite,
              endDate.timeIntervalSince1970.isFinite,
              startDate <= endDate else {

            throw PlaceVisitQueryError.invalidDateRange
        }
    }

    func overlaps(
        _ visit: PlaceVisitRecord,
        startDate: Date,
        endDate: Date
    ) -> Bool {

        guard visit.startedAt <= endDate else {
            return false
        }

        guard let visitEnd = visit.endedAt else {

            // Active visits continue beyond the
            // requested range's starting boundary.
            return true
        }

        return visitEnd >= startDate
    }

    func sortedVisits(
        _ visits: [PlaceVisitRecord]
    ) -> [PlaceVisitRecord] {

        visits.sorted { lhs, rhs in

            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }

            return lhs.id.uuidString
                < rhs.id.uuidString
        }
    }
}

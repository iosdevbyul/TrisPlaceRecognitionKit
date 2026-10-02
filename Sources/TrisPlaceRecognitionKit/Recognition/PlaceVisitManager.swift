//
//  PlaceVisitManager.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Combine
import Foundation
import TrisLocationKit

@MainActor
public final class PlaceVisitManager: ObservableObject {

    @Published
    public private(set) var recognizedPlaces: [RecognizedPlace] = []

    @Published
    public private(set) var activeVisits: [PlaceVisitRecord] = []

    @Published
    public private(set) var isMonitoring = false

    @Published
    public private(set)
    var isBackgroundRecognitionEnabled = false

    @Published
    public private(set) var lastErrorMessage: String?

    @Published
    public private(set) var lastVisitErrorMessage: String?

    @Published
    public private(set)
    var lastBackgroundErrorMessage: String?

    private let recognitionService:
        PlaceRecognitionService

    private let monitor:
        PlaceRecognitionMonitor

    private let coordinator:
        PlaceVisitCoordinator

    private let visitStore:
        any PlaceVisitStoring

    private let backgroundRecognitionPolicy:
        BackgroundRecognitionPolicy

    private let backgroundMonitoringService:
        BackgroundRegionMonitoringService

    private let backgroundEventProcessor:
        BackgroundRecognitionEventProcessor

    private var backgroundEventTask:
        Task<Void, Never>?

    private var restorationTask:
        Task<[PlaceVisitRecord], Error>?

    private var hasRestoredVisits = false

    public convenience init(
        recognitionService: PlaceRecognitionService,
        visitStore: any PlaceVisitStoring,
        recognitionPolicy: PlaceRecognitionPolicy = .gpsConstrained,
        visitPolicy: PlaceVisitPolicy = .init(),
        refreshInterval: TimeInterval = 15,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy = .init()
    ) {

        self.init(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: recognitionPolicy,
            visitPolicy: visitPolicy,
            refreshInterval: refreshInterval,
            backgroundRecognitionPolicy:
                backgroundRecognitionPolicy,
            backgroundMonitor:
                CoreLocationBackgroundRegionMonitor()
        )
    }

    init(
        recognitionService: PlaceRecognitionService,
        visitStore: any PlaceVisitStoring,
        recognitionPolicy: PlaceRecognitionPolicy,
        visitPolicy: PlaceVisitPolicy,
        refreshInterval: TimeInterval,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy,
        backgroundMonitor:
            any BackgroundRegionMonitoring
    ) {

        let coordinator =
            PlaceVisitCoordinator(
                store: visitStore,
                policy: visitPolicy
            )

        let monitor =
            PlaceRecognitionMonitor(
                recognitionService:
                    recognitionService,
                policy:
                    recognitionPolicy,
                refreshInterval:
                    refreshInterval
            )

        self.recognitionService =
            recognitionService

        self.visitStore =
            visitStore

        self.coordinator =
            coordinator

        self.monitor =
            monitor

        self.backgroundRecognitionPolicy =
            backgroundRecognitionPolicy

        self.backgroundMonitoringService =
            BackgroundRegionMonitoringService(
                monitor: backgroundMonitor
            )

        self.backgroundEventProcessor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    recognitionPolicy
            )

        bindMonitor()

        monitor.onSuccessfulRecognition = {
            [weak self] places, observedAt in

            guard let self else {
                return
            }

            try await self
                .processSuccessfulObservation(
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
        refreshInterval: TimeInterval = 15,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy = .init()
    ) throws {

        let visitStore =
            try SwiftDataPlaceVisitStore()

        self.init(
            recognitionService:
                recognitionService,
            visitStore:
                visitStore,
            recognitionPolicy:
                recognitionPolicy,
            visitPolicy:
                visitPolicy,
            refreshInterval:
                refreshInterval,
            backgroundRecognitionPolicy:
                backgroundRecognitionPolicy
        )
    }

    // MARK: - Foreground Monitoring

    @discardableResult
    public func restore()
        async throws -> [PlaceVisitRecord] {

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

    // MARK: - Background Recognition

    /// Starts low-power background place recognition.
    ///
    /// This does not start continuous location updates.
    /// A single location snapshot is requested only when
    /// the monitored place set must be calculated.
    public func startBackgroundRecognition()
        async throws {

        try await restoreIfNeeded()

        if isBackgroundRecognitionEnabled {

            try await refreshBackgroundRecognition()

            return
        }

        do {

            try await synchronizeBackgroundMonitoring()

            isBackgroundRecognitionEnabled = true
            lastBackgroundErrorMessage = nil

            startBackgroundEventListening()

        } catch {

            lastBackgroundErrorMessage =
                error.localizedDescription

            throw error
        }
    }

    /// Recalculates which registered places should be
    /// monitored by the system.
    ///
    /// No work is performed when background recognition
    /// has not been enabled.
    public func refreshBackgroundRecognition()
        async throws {

        guard isBackgroundRecognitionEnabled else {
            return
        }

        do {

            try await synchronizeBackgroundMonitoring()

            lastBackgroundErrorMessage = nil

        } catch {

            lastBackgroundErrorMessage =
                error.localizedDescription

            // synchronizeBackgroundMonitoring() can mark
            // the feature disabled when a fatal condition
            // makes background monitoring unusable.
            if !isBackgroundRecognitionEnabled {

                backgroundEventTask?.cancel()
                backgroundEventTask = nil
            }

            throw error
        }
    }

    /// Stops only background place recognition.
    ///
    /// Foreground recognition is controlled separately
    /// through start(), refresh(), and stop().
    public func stopBackgroundRecognition()
        async {

        backgroundEventTask?.cancel()
        backgroundEventTask = nil

        await backgroundMonitoringService.stop()

        isBackgroundRecognitionEnabled = false
        lastBackgroundErrorMessage = nil
    }

    // MARK: - Visit Queries

    public func fetchVisits()
        async throws -> [PlaceVisitRecord] {

        let visits =
            try await visitStore.fetchAll()

        return sortedVisits(
            visits
        )
    }

    public func fetchVisits(
        for placeID: UUID
    ) async throws -> [PlaceVisitRecord] {

        let visits =
            try await visitStore.fetchAll()

        return sortedVisits(
            visits.filter {
                $0.placeID == placeID
            }
        )
    }

    public func fetchVisits(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PlaceVisitRecord] {

        try validateDateRange(
            from: startDate,
            to: endDate
        )

        let visits =
            try await visitStore.fetchAll()

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

    public func fetchVisits(
        for placeID: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PlaceVisitRecord] {

        try validateDateRange(
            from: startDate,
            to: endDate
        )

        let visits =
            try await visitStore.fetchAll()

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

    public func fetchLatestVisit(
        for placeID: UUID
    ) async throws -> PlaceVisitRecord? {

        let visits =
            try await visitStore.fetchAll()

        return visits
            .filter {
                $0.placeID == placeID
            }
            .max { lhs, rhs in

                if lhs.startedAt
                    != rhs.startedAt {

                    return lhs.startedAt
                        < rhs.startedAt
                }

                return lhs.id.uuidString
                    < rhs.id.uuidString
            }
    }

    public func fetchEvents()
        async throws -> [PlaceVisitEvent] {

        let events =
            try await visitStore.fetchEvents()

        return events.sorted { lhs, rhs in

            if lhs.occurredAt
                != rhs.occurredAt {

                return lhs.occurredAt
                    < rhs.occurredAt
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

            let restored =
                try await restorationTask.value

            activeVisits = restored
            hasRestoredVisits = true

            return
        }

        let coordinator =
            self.coordinator

        let task = Task {

            try await coordinator.restore()
        }

        restorationTask = task

        do {

            let restored =
                try await task.value

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

        activeVisits =
            try await coordinator.activeVisits()
    }

    func synchronizeBackgroundMonitoring()
        async throws {

        let places =
            try await recognitionService
                .fetchRegisteredPlacesForBackgroundMonitoring()

        guard !places.isEmpty else {

            await backgroundMonitoringService
                .stop()

            return
        }

        do {

            try validateBackgroundAuthorization()

        } catch {

            // Authorization failures are terminal for
            // background recognition. Do not leave stale
            // system monitoring active.
            await backgroundMonitoringService
                .stop()

            isBackgroundRecognitionEnabled = false

            throw error
        }

        guard
            let currentLocation =
                try await recognitionService
                    .requestBackgroundMonitoringLocation()
        else {

            // A poor location snapshot is temporary.
            // Preserve the currently registered regions
            // and allow a later retry.
            throw BackgroundRecognitionManagerError
                .unacceptableLocationSnapshot
        }

        let prioritizedPlaceIDs =
            Set(
                activeVisits.map(
                    \.placeID
                )
            )

        let candidates =
            BackgroundMonitoringCandidateSelector
                .select(
                    from: places,
                    currentLatitude:
                        currentLocation.latitude,
                    currentLongitude:
                        currentLocation.longitude,
                    prioritizedPlaceIDs:
                        prioritizedPlaceIDs,
                    policy:
                        backgroundRecognitionPolicy
                )

        let requiresCandidateRefresh =
            places.count > candidates.count

        do {

            try await backgroundMonitoringService
                .synchronize(
                    candidates: candidates,
                    requiresCandidateRefresh:
                        requiresCandidateRefresh
                )

        } catch {

            // BackgroundRegionMonitoringService already
            // rolls back its system monitoring when this
            // operation fails. Keep manager state aligned
            // with that terminal failure.
            isBackgroundRecognitionEnabled = false

            throw error
        }
    }

    func validateBackgroundAuthorization()
        throws {

        switch recognitionService
            .locationAuthorizationStatus {

        case .authorizedAlways:

            return

        case .notDetermined,
             .authorizedWhenInUse:

            recognitionService
                .requestAlwaysLocationAuthorization()

            throw BackgroundRecognitionManagerError
                .alwaysAuthorizationRequired

        case .denied:

            throw BackgroundRecognitionManagerError
                .authorizationDenied

        case .restricted:

            throw BackgroundRecognitionManagerError
                .authorizationRestricted

        case .unknown:

            throw BackgroundRecognitionManagerError
                .authorizationUnknown
        }
    }

    func startBackgroundEventListening() {

        backgroundEventTask?.cancel()

        let events =
            backgroundMonitoringService
                .events()

        backgroundEventTask = Task {
            [weak self] in

            do {

                for try await trigger in events {

                    guard !Task.isCancelled else {
                        return
                    }

                    guard let self else {
                        return
                    }

                    do {

                        try await self
                            .processBackgroundTrigger(
                                trigger
                            )

                        self
                            .lastBackgroundErrorMessage =
                            nil

                    } catch is CancellationError {

                        return

                    } catch {

                        self
                            .lastBackgroundErrorMessage =
                            error.localizedDescription

                        // A fatal synchronization failure
                        // can disable monitoring from inside
                        // processBackgroundTrigger().
                        if !self
                            .isBackgroundRecognitionEnabled {

                            self.backgroundEventTask = nil

                            return
                        }
                    }
                }

                guard !Task.isCancelled,
                      let self else {
                    return
                }

                // An unexpected normal stream termination
                // means there is no longer an event source.
                await self
                    .backgroundMonitoringService
                    .stop()

                self
                    .isBackgroundRecognitionEnabled =
                    false

                self.backgroundEventTask = nil

            } catch is CancellationError {

                return

            } catch {

                guard !Task.isCancelled,
                      let self else {
                    return
                }

                self.lastBackgroundErrorMessage =
                    error.localizedDescription

                // The stream itself failed. System
                // monitoring must not remain active while
                // the manager claims the feature is stopped.
                await self
                    .backgroundMonitoringService
                    .stop()

                self
                    .isBackgroundRecognitionEnabled =
                    false

                self.backgroundEventTask = nil
            }
        }
    }

    func processBackgroundTrigger(
        _ trigger: BackgroundRecognitionTrigger
    ) async throws {

        switch trigger {

        case .significantLocationChange:

            // Significant movement is used only to
            // recalculate the small set of system-
            // monitored candidate regions.
            try await synchronizeBackgroundMonitoring()

        case .monitoredRegionEntered,
             .monitoredRegionExited:

            _ = try await backgroundEventProcessor
                .handle(
                    trigger
                )

            activeVisits =
                try await coordinator
                    .activeVisits()
        }
    }

    func validateDateRange(
        from startDate: Date,
        to endDate: Date
    ) throws {

        guard
            startDate
                .timeIntervalSince1970
                .isFinite,
            endDate
                .timeIntervalSince1970
                .isFinite,
            startDate <= endDate
        else {

            throw PlaceVisitQueryError
                .invalidDateRange
        }
    }

    func overlaps(
        _ visit: PlaceVisitRecord,
        startDate: Date,
        endDate: Date
    ) -> Bool {

        guard
            visit.startedAt <= endDate
        else {
            return false
        }

        guard
            let visitEnd =
                visit.endedAt
        else {

            return true
        }

        return visitEnd >= startDate
    }

    func sortedVisits(
        _ visits: [PlaceVisitRecord]
    ) -> [PlaceVisitRecord] {

        visits.sorted { lhs, rhs in

            if lhs.startedAt
                != rhs.startedAt {

                return lhs.startedAt
                    < rhs.startedAt
            }

            return lhs.id.uuidString
                < rhs.id.uuidString
        }
    }
}

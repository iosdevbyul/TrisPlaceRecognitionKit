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
}

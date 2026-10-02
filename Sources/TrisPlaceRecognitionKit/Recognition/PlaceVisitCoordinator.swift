//
//  PlaceVisitCoordinator.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

public enum PlaceVisitCoordinatorError: Error, Sendable, Equatable {
    case notRestored
    case alreadyRestored
}

public actor PlaceVisitCoordinator {

    private let store: any PlaceVisitStoring
    private let policy: PlaceVisitPolicy

    private var machine: PlaceVisitStateMachine?

    // Serialize operations across actor suspension
    // points, including asynchronous storage calls.
    private var isRunningOperation = false

    private var waitingOperations:
        [CheckedContinuation<Void, Never>] = []

    public init(
        store: any PlaceVisitStoring,
        policy: PlaceVisitPolicy = .init()
    ) {
        self.store = store
        self.policy = policy
    }

    // Call before starting recognition monitoring.
    @discardableResult
    public func restore() async throws -> [PlaceVisitRecord] {

        await acquireOperation()

        defer {
            releaseOperation()
        }

        try Task.checkCancellation()

        guard machine == nil else {
            throw PlaceVisitCoordinatorError.alreadyRestored
        }

        let records = try await store.fetchActiveVisits()

        let restoredMachine = try PlaceVisitStateMachine(
            policy: policy,
            restoring: records
        )

        try Task.checkCancellation()

        machine = restoredMachine

        return restoredMachine.activeVisits
    }

    // Call only after a successful recognition request.
    // An empty array is valid only when recognition
    // succeeded but no registered places matched.
    @discardableResult
    public func processSuccessfulObservation(
        _ recognizedPlaces: [RecognizedPlace],
        at timestamp: Date = Date()
    ) async throws -> PlaceVisitUpdate {

        await acquireOperation()

        defer {
            releaseOperation()
        }

        try Task.checkCancellation()

        guard let machine else {
            throw PlaceVisitCoordinatorError.notRestored
        }

        // Work on a copy. If storage fails, the
        // original machine remains unchanged.
        var candidate = machine

        let update = candidate.process(
            recognizedPlaces,
            at: timestamp
        )

        if !update.events.isEmpty
            || !update.startedVisits.isEmpty
            || !update.endedVisits.isEmpty {

            try await store.apply(update)
        }

        // Commit the candidate only after persistence
        // has succeeded.
        self.machine = candidate

        return update
    }

    // Used only after a background region transition
    // has triggered a successful recognition request.
    //
    // The region event by itself must never be passed
    // into the visit state machine as arrival/departure.
    @discardableResult
    func processVerifiedBackgroundObservation(
        _ recognizedPlaces: [RecognizedPlace],
        trigger: BackgroundRecognitionTrigger,
        at timestamp: Date = Date()
    ) async throws -> PlaceVisitUpdate {

        await acquireOperation()

        defer {
            releaseOperation()
        }

        try Task.checkCancellation()

        guard let machine else {
            throw PlaceVisitCoordinatorError.notRestored
        }

        var candidate = machine

        let update =
            candidate
                .processVerifiedBackgroundObservation(
                    recognizedPlaces,
                    trigger: trigger,
                    at: timestamp
                )

        if !update.events.isEmpty
            || !update.startedVisits.isEmpty
            || !update.endedVisits.isEmpty {

            try await store.apply(
                update
            )
        }

        // Preserve the same transactional behavior as
        // foreground processing. Never advance the state
        // machine if persistence fails.
        self.machine = candidate

        return update
    }

    public func activeVisits() throws -> [PlaceVisitRecord] {

        guard let machine else {
            throw PlaceVisitCoordinatorError.notRestored
        }

        return machine.activeVisits
    }
}

private extension PlaceVisitCoordinator {

    func acquireOperation() async {

        if !isRunningOperation {

            isRunningOperation = true
            return
        }

        await withCheckedContinuation { continuation in
            waitingOperations.append(
                continuation
            )
        }
    }

    func releaseOperation() {

        if waitingOperations.isEmpty {

            isRunningOperation = false

        } else {

            let next = waitingOperations.removeFirst()

            // Transfer ownership to the next waiting
            // operation without opening a race window.
            next.resume()
        }
    }
}

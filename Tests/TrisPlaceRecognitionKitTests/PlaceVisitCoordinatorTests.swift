//
//  PlaceVisitCoordinatorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceVisitCoordinatorTests {

    @Test
    func requiresRestorationBeforeProcessing() async throws {

        let store = InMemoryPlaceVisitStore()

        let coordinator = PlaceVisitCoordinator(
            store: store
        )

        let gym = try makePlace()

        await #expect(
            throws: PlaceVisitCoordinatorError.notRestored
        ) {
            _ = try await coordinator
                .processSuccessfulObservation(
                    [recognize(gym)],
                    at: time(0)
                )
        }

        #expect(
            try await store.fetchAll().isEmpty
        )
    }

    @Test
    func restoresActiveVisitWithoutDuplicateArrival() async throws {

        let store = InMemoryPlaceVisitStore()
        let gym = try makePlace()

        let policy = PlaceVisitPolicy(
            arrivalConfirmationInterval: 0,
            departureConfirmationInterval: 60
        )

        let firstCoordinator = PlaceVisitCoordinator(
            store: store,
            policy: policy
        )

        _ = try await firstCoordinator.restore()

        let arrival = try await firstCoordinator
            .processSuccessfulObservation(
                [recognize(gym)],
                at: time(0)
            )

        let originalRecord = try #require(
            arrival.startedVisits.first
        )

        // Simulate a new application session.
        let secondCoordinator = PlaceVisitCoordinator(
            store: store,
            policy: policy
        )

        let restored = try await secondCoordinator.restore()

        #expect(restored == [originalRecord])

        let observation = try await secondCoordinator
            .processSuccessfulObservation(
                [recognize(gym)],
                at: time(3600)
            )

        #expect(observation.events.isEmpty)

        let activeVisits = try await secondCoordinator.activeVisits()
        let events = try await store.fetchEvents()

        #expect(activeVisits == [originalRecord])
        #expect(events.count == 1)
        #expect(events.first?.kind == .arrived)
    }

    @Test
    func confirmsDepartureFromNewObservationsAfterRestart() async throws {

        let store = InMemoryPlaceVisitStore()
        let gym = try makePlace()

        let policy = PlaceVisitPolicy(
            arrivalConfirmationInterval: 0,
            departureConfirmationInterval: 60,
            maximumObservationGap: 45
        )

        let firstCoordinator = PlaceVisitCoordinator(
            store: store,
            policy: policy
        )

        _ = try await firstCoordinator.restore()

        let arrival = try await firstCoordinator
            .processSuccessfulObservation(
                [recognize(gym)],
                at: time(0)
            )

        let originalID = try #require(
            arrival.startedVisits.first?.id
        )

        let secondCoordinator = PlaceVisitCoordinator(
            store: store,
            policy: policy
        )

        _ = try await secondCoordinator.restore()

        // Recognition resumes after a long interruption.
        let firstMissing = try await secondCoordinator
            .processSuccessfulObservation(
                [],
                at: time(3600)
            )

        #expect(firstMissing.events.isEmpty)

        let stillMissing = try await secondCoordinator
            .processSuccessfulObservation(
                [],
                at: time(3630)
            )

        #expect(stillMissing.events.isEmpty)

        let departure = try await secondCoordinator
            .processSuccessfulObservation(
                [],
                at: time(3660)
            )

        #expect(departure.events.count == 1)
        #expect(departure.events.first?.kind == .departed)
        #expect(departure.events.first?.visitID == originalID)

        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(activeVisits.isEmpty)
        #expect(events.count == 2)
    }

    @Test
    func doesNotRestoreTwice() async throws {

        let coordinator = PlaceVisitCoordinator(
            store: InMemoryPlaceVisitStore()
        )

        _ = try await coordinator.restore()

        await #expect(
            throws: PlaceVisitCoordinatorError.alreadyRestored
        ) {
            _ = try await coordinator.restore()
        }
    }

    @Test
    func failedPersistenceDoesNotAdvanceStateMachine() async throws {

        let store = FailOncePlaceVisitStore()

        let coordinator = PlaceVisitCoordinator(
            store: store,
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        _ = try await coordinator.restore()

        let gym = try makePlace()

        await #expect(
            throws: CoordinatorTestError.simulatedWriteFailure
        ) {
            _ = try await coordinator
                .processSuccessfulObservation(
                    [recognize(gym)],
                    at: time(0)
                )
        }

        #expect(
            try await coordinator.activeVisits().isEmpty
        )

        #expect(
            try await store.fetchEvents().isEmpty
        )

        // Retry the exact same observation.
        let retry = try await coordinator
            .processSuccessfulObservation(
                [recognize(gym)],
                at: time(0)
            )

        #expect(retry.events.count == 1)
        #expect(retry.events.first?.kind == .arrived)

        #expect(
            try await store.fetchActiveVisits().count == 1
        )
    }

    @Test
    func rejectsDuplicateActivePlacesDuringRestoration() async throws {

        let placeID = UUID()

        let first = PlaceVisitRecord(
            placeID: placeID,
            startedAt: time(0),
            arrivalEvidence: .bssid
        )

        let second = PlaceVisitRecord(
            placeID: placeID,
            startedAt: time(15),
            arrivalEvidence: .ssid
        )

        let store = StubPlaceVisitStore(
            activeRecords: [first, second]
        )

        let coordinator = PlaceVisitCoordinator(
            store: store
        )

        await #expect(
            throws: PlaceVisitRestorationError.duplicatePlace
        ) {
            _ = try await coordinator.restore()
        }
    }

    @available(iOS 17.0, *)
    @Test
    func restoresVisitFromDiskAfterReopeningDatabase() async throws {

        let directoryURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: directoryURL
            )
        }

        let databaseURL = directoryURL
            .appendingPathComponent("visits.sqlite")

        let gym = try makePlace()

        let policy = PlaceVisitPolicy(
            arrivalConfirmationInterval: 0,
            departureConfirmationInterval: 60
        )

        var originalVisitID: UUID?

        // First application session.
        do {

            let store = try makeDiskStore(
                databaseURL: databaseURL
            )

            let coordinator = PlaceVisitCoordinator(
                store: store,
                policy: policy
            )

            _ = try await coordinator.restore()

            let arrival = try await coordinator
                .processSuccessfulObservation(
                    [recognize(gym)],
                    at: time(0)
                )

            originalVisitID = try #require(
                arrival.startedVisits.first?.id
            )
        }

        let expectedVisitID = try #require(
            originalVisitID
        )

        // Second application session using the same DB.
        do {

            let store = try makeDiskStore(
                databaseURL: databaseURL
            )

            let coordinator = PlaceVisitCoordinator(
                store: store,
                policy: policy
            )

            let restored = try await coordinator.restore()

            #expect(restored.count == 1)
            #expect(restored.first?.id == expectedVisitID)

            let recognized = try await coordinator
                .processSuccessfulObservation(
                    [recognize(gym)],
                    at: time(3600)
                )

            #expect(recognized.events.isEmpty)

            _ = try await coordinator
                .processSuccessfulObservation(
                    [],
                    at: time(3615)
                )

            _ = try await coordinator
                .processSuccessfulObservation(
                    [],
                    at: time(3645)
                )

            let departure = try await coordinator
                .processSuccessfulObservation(
                    [],
                    at: time(3675)
                )

            #expect(
                departure.events.first?.visitID
                    == expectedVisitID
            )

            #expect(
                departure.events.first?.kind
                    == .departed
            )

            let visits = try await store.fetchAll()
            let events = try await store.fetchEvents()

            #expect(visits.count == 1)
            #expect(visits.first?.id == expectedVisitID)
            #expect(visits.first?.endedAt == time(3675))

            #expect(events.count == 2)
            #expect(events.map(\.kind) == [.arrived, .departed])
        }
    }
}

private extension PlaceVisitCoordinatorTests {

    func time(
        _ seconds: TimeInterval
    ) -> Date {

        Date(
            timeIntervalSince1970: 1_000_000 + seconds
        )
    }

    func makePlace() throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName("Gym"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )
    }

    func recognize(
        _ place: RegisteredPlace
    ) -> RecognizedPlace {

        RecognizedPlace(
            place: place,
            distanceMeters: nil,
            evidence: .gpsOnlyNoWiFiConfigured
        )
    }
}

@available(iOS 17.0, *)
private extension PlaceVisitCoordinatorTests {

    func makeDiskStore(
        databaseURL: URL
    ) throws -> SwiftDataPlaceVisitStore {

        let schema = Schema([
            StoredPlaceVisit.self,
            StoredPlaceVisitEvent.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        return SwiftDataPlaceVisitStore(
            modelContainer: container
        )
    }
}

private enum CoordinatorTestError: Error {
    case simulatedWriteFailure
}

private actor FailOncePlaceVisitStore: PlaceVisitStoring {

    private let underlying = InMemoryPlaceVisitStore()
    private var shouldFail = true

    func apply(
        _ update: PlaceVisitUpdate
    ) async throws {

        if shouldFail {

            shouldFail = false

            throw CoordinatorTestError.simulatedWriteFailure
        }

        try await underlying.apply(update)
    }

    func fetchAll() async throws -> [PlaceVisitRecord] {
        try await underlying.fetchAll()
    }

    func fetchActiveVisits() async throws -> [PlaceVisitRecord] {
        try await underlying.fetchActiveVisits()
    }

    func fetchEvents() async throws -> [PlaceVisitEvent] {
        try await underlying.fetchEvents()
    }
}

private struct StubPlaceVisitStore: PlaceVisitStoring {

    let activeRecords: [PlaceVisitRecord]

    func apply(
        _ update: PlaceVisitUpdate
    ) async throws {}

    func fetchAll() async throws -> [PlaceVisitRecord] {
        activeRecords
    }

    func fetchActiveVisits() async throws -> [PlaceVisitRecord] {
        activeRecords
    }

    func fetchEvents() async throws -> [PlaceVisitEvent] {
        []
    }
}

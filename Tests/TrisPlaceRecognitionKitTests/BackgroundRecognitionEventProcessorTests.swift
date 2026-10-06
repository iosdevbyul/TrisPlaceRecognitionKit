//
//  BackgroundRecognitionEventProcessorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct BackgroundRecognitionEventProcessorTests {

    @Test
    func verifiedEntryConfirmsArrivalWithoutWaitingForForegroundInterval()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network: WiFiNetwork(
                    ssid: "GYM_WIFI",
                    bssid: nil
                )
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store: visitStore,
                policy: PlaceVisitPolicy()
            )

        _ = try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let update =
            try await processor.handle(
                .monitoredRegionEntered(
                    placeID: gym.id
                ),
                at: time(100)
            )

        #expect(
            update.events.count == 1
        )

        #expect(
            update.events.first?.kind
                == .arrived
        )

        #expect(
            update.startedVisits.count == 1
        )

        #expect(
            update.startedVisits.first?.placeID
                == gym.id
        )

        let activeVisits =
            try await coordinator.activeVisits()

        #expect(
            activeVisits.count == 1
        )

        #expect(
            activeVisits.first?.placeID
                == gym.id
        )
    }

    @Test
    func verifiedExitConfirmsDepartureWithoutWaitingForForegroundInterval()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network: nil
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let existingVisit =
            try await seedActiveVisit(
                place: gym,
                store: visitStore
            )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store: visitStore,
                policy: PlaceVisitPolicy()
            )

        let restored =
            try await coordinator.restore()

        #expect(
            restored == [
                existingVisit
            ]
        )

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let update =
            try await processor.handle(
                .monitoredRegionExited(
                    placeID: gym.id
                ),
                at: time(120)
            )

        #expect(
            update.events.count == 1
        )

        #expect(
            update.events.first?.kind
                == .departed
        )

        #expect(
            update.endedVisits.count == 1
        )

        #expect(
            update.endedVisits.first?.id
                == existingVisit.id
        )

        let activeVisits =
            try await coordinator.activeVisits()

        #expect(activeVisits.isEmpty)

        let storedVisits =
            try await visitStore.fetchAll()

        let storedVisit =
            try #require(
                storedVisits.first {
                    $0.id == existingVisit.id
                }
            )

        #expect(
            storedVisit.endedAt
                == time(120)
        )
    }

    @Test
    func significantLocationChangeRevalidatesActiveVisit()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network:
                    nil
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym =
            try makePlace(
                name:
                    "Gym",
                ssid:
                    "GYM_WIFI"
            )

        try await placeStore.save(
            gym
        )

        let existingVisit =
            try await seedActiveVisit(
                place:
                    gym,
                store:
                    visitStore
            )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        _ =
            try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let update =
            try await processor.handle(
                .significantLocationChange,
                at:
                    time(600)
            )

        #expect(
            update.events.count
                == 1
        )

        #expect(
            update.events.first?.kind
                == .departed
        )

        #expect(
            update.endedVisits.count
                == 1
        )

        #expect(
            update.endedVisits.first?.id
                == existingVisit.id
        )

        #expect(
            try await coordinator
                .activeVisits()
                .isEmpty
        )
    }
    
    @Test
    func delayedBackgroundRecognitionUsesCompletionTimeForObservation()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            SuspendedWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let home =
            try makePlace(
                name:
                    "Home",
                ssid:
                    "HOME_WIFI"
            )

        try await placeStore.save(
            home
        )

        let existingVisit =
            try await seedActiveVisit(
                place:
                    home,
                store:
                    visitStore
            )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        _ =
            try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let backgroundTask =
            Task {
                try await processor.handle(
                    .significantLocationChange
                )
            }

        await wifiProvider
            .waitUntilRequestStarts()

        // Simulate a newer foreground observation being
        // processed while background recognition is still
        // waiting for Wi-Fi.
        _ =
            try await coordinator
                .processSuccessfulObservation(
                    [
                        RecognizedPlace(
                            place:
                                home,
                            distanceMeters:
                                nil,
                            evidence:
                                .ssid
                        )
                    ],
                    at:
                        Date()
                )

        await wifiProvider
            .resume(
                with:
                    nil
            )

        let result =
            try await backgroundTask.value

        #expect(
            result
                .endedVisits
                .count
                == 1
        )

        #expect(
            result
                .endedVisits
                .first?
                .id
                == existingVisit.id
        )

        #expect(
            result
                .events
                .first?
                .kind
                == .departed
        )

        #expect(
            try await coordinator
                .activeVisits()
                .isEmpty
        )
    }
    
    @Test
    func backgroundRoundTripPersistsHomeGymHomeVisitHistory()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let home =
            try makePlace(
                name:
                    "Home",
                ssid:
                    "HOME_WIFI"
            )

        let gym =
            try makePlace(
                name:
                    "Gym",
                ssid:
                    "GYM_WIFI"
            )

        try await placeStore.save(
            home
        )

        try await placeStore.save(
            gym
        )

        let initialHomeVisit =
            try await seedActiveVisit(
                place:
                    home,
                store:
                    visitStore
            )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        _ =
            try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        // 10:00 - Home departure confirmed.
        wifiProvider.network =
            nil

        let homeExitUpdate =
            try await processor.handle(
                .monitoredRegionExited(
                    placeID:
                        home.id
                ),
                at:
                    time(600)
            )

        #expect(
            homeExitUpdate
                .endedVisits
                .first?
                .id
                == initialHomeVisit.id
        )

        // 10:10 - Gym arrival confirmed.
        wifiProvider.network =
            WiFiNetwork(
                ssid:
                    "GYM_WIFI",
                bssid:
                    nil
            )

        let gymEntryUpdate =
            try await processor.handle(
                .monitoredRegionEntered(
                    placeID:
                        gym.id
                ),
                at:
                    time(1_200)
            )

        let gymVisit =
            try #require(
                gymEntryUpdate
                    .startedVisits
                    .first
            )

        #expect(
            gymVisit.placeID
                == gym.id
        )

        // 11:00 - Gym departure confirmed.
        wifiProvider.network =
            nil

        let gymExitUpdate =
            try await processor.handle(
                .monitoredRegionExited(
                    placeID:
                        gym.id
                ),
                at:
                    time(4_200)
            )

        let completedGymVisit =
            try #require(
                gymExitUpdate
                    .endedVisits
                    .first
            )

        #expect(
            completedGymVisit.id
                == gymVisit.id
        )

        #expect(
            completedGymVisit.duration
                == 3_000
        )

        // 11:10 - Home arrival confirmed again.
        wifiProvider.network =
            WiFiNetwork(
                ssid:
                    "HOME_WIFI",
                bssid:
                    nil
            )

        let homeReturnUpdate =
            try await processor.handle(
                .monitoredRegionEntered(
                    placeID:
                        home.id
                ),
                at:
                    time(4_800)
            )

        let returnedHomeVisit =
            try #require(
                homeReturnUpdate
                    .startedVisits
                    .first
            )

        #expect(
            returnedHomeVisit.placeID
                == home.id
        )

        // Simulate opening the app again after the
        // background round trip.
        let restoredCoordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        let restoredActiveVisits =
            try await restoredCoordinator
                .restore()

        #expect(
            restoredActiveVisits.count
                == 1
        )

        #expect(
            restoredActiveVisits.first?.id
                == returnedHomeVisit.id
        )

        #expect(
            restoredActiveVisits.first?.placeID
                == home.id
        )

        let storedVisits =
            try await visitStore
                .fetchAll()

        #expect(
            storedVisits.count
                == 3
        )

        let storedInitialHomeVisit =
            try #require(
                storedVisits.first {
                    $0.id
                        == initialHomeVisit.id
                }
            )

        #expect(
            storedInitialHomeVisit.endedAt
                == time(600)
        )

        let storedGymVisit =
            try #require(
                storedVisits.first {
                    $0.id
                        == gymVisit.id
                }
            )

        #expect(
            storedGymVisit.startedAt
                == time(1_200)
        )

        #expect(
            storedGymVisit.endedAt
                == time(4_200)
        )

        #expect(
            storedGymVisit.duration
                == 3_000
        )

        let storedReturnedHomeVisit =
            try #require(
                storedVisits.first {
                    $0.id
                        == returnedHomeVisit.id
                }
            )

        #expect(
            storedReturnedHomeVisit.startedAt
                == time(4_800)
        )

        #expect(
            storedReturnedHomeVisit.endedAt
                == nil
        )

        let events =
            try await visitStore
                .fetchEvents()

        #expect(
            events.count
                == 5
        )

        #expect(
            events.filter {
                $0.kind == .arrived
            }.count
                == 3
        )

        #expect(
            events.filter {
                $0.kind == .departed
            }.count
                == 2
        )
    }
    
    @Test
    func regionExitEndsActiveVisitWithoutRecognition()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network:
                    WiFiNetwork(
                        ssid:
                            "HOME_WIFI",
                        bssid:
                            nil
                    )
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let home =
            try makePlace(
                name:
                    "Home",
                ssid:
                    "HOME_WIFI"
            )

        try await placeStore.save(
            home
        )

        let existingVisit =
            try await seedActiveVisit(
                place:
                    home,
                store:
                    visitStore
            )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        _ =
            try await coordinator
                .restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let result =
            try await processor.handle(
                .monitoredRegionExited(
                    placeID:
                        home.id
                ),
                at:
                    time(120)
            )

        #expect(
            wifiProvider
                .currentNetworkCallCount
                == 0
        )

        #expect(
            result
                .endedVisits
                .count
                == 1
        )

        #expect(
            result
                .endedVisits
                .first?
                .id
                == existingVisit.id
        )

        #expect(
            result
                .events
                .first?
                .kind
                == .departed
        )

        #expect(
            try await coordinator
                .activeVisits()
                .isEmpty
        )
    }
    
    @Test
    func regionEntryStartsVisitWithoutRecognition()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network:
                    nil
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym =
            try makePlace(
                name:
                    "Gym",
                ssid:
                    "GYM_WIFI"
            )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    visitStore
            )

        _ =
            try await coordinator
                .restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .wifiFirst
            )

        let result =
            try await processor.handle(
                .monitoredRegionEntered(
                    placeID:
                        gym.id
                ),
                at:
                    time(120)
            )

        #expect(
            wifiProvider
                .currentNetworkCallCount
                == 0
        )

        #expect(
            result
                .startedVisits
                .count
                == 1
        )

        #expect(
            result
                .startedVisits
                .first?
                .placeID
                == gym.id
        )

        #expect(
            result
                .events
                .count
                == 1
        )

        #expect(
            result
                .events
                .first?
                .kind
                == .arrived
        )

        #expect(
            try await coordinator
                .activeVisits()
                .first?
                .placeID
                == gym.id
        )
    }
}

private extension
    BackgroundRecognitionEventProcessorTests {

    func makePlace(
        name: String,
        ssid: String?
    ) throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName(
                name
            ),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity:
                PlaceNetworkIdentity(
                    ssid: ssid,
                    bssid: nil
                )
        )
    }

    func seedActiveVisit(
        place: RegisteredPlace,
        store: InMemoryPlaceVisitStore
    ) async throws -> PlaceVisitRecord {

        let record =
            PlaceVisitRecord(
                placeID: place.id,
                startedAt: time(0),
                arrivalEvidence:
                    place.networkIdentities.isEmpty
                    ? .gpsOnlyNoWiFiConfigured
                    : .ssid
            )

        let event =
            PlaceVisitEvent(
                visitID: record.id,
                placeID: place.id,
                kind: .arrived,
                occurredAt: record.startedAt
            )

        try await store.apply(
            PlaceVisitUpdate(
                events: [
                    event
                ],
                startedVisits: [
                    record
                ]
            )
        )

        return record
    }

    func time(
        _ seconds: TimeInterval
    ) -> Date {

        Date(
            timeIntervalSince1970:
                1_000_000 + seconds
        )
    }
}

private enum
    BackgroundRecognitionProcessorTestError:
    Error {

    case locationUnavailable
}

private actor SuspendedWiFiProvider:
    WiFiProviding {

    private var continuation:
        CheckedContinuation<
            WiFiNetwork?,
            Never
        >?

    private var requestStarted = false

    private var waiters:
        [
            CheckedContinuation<
                Void,
                Never
            >
        ] = []

    func currentNetwork()
        async
        -> WiFiNetwork? {

        requestStarted =
            true

        let currentWaiters =
            waiters

        waiters.removeAll()

        for waiter in currentWaiters {
            waiter.resume()
        }

        return await withCheckedContinuation {
            continuation in

            self.continuation =
                continuation
        }
    }

    func waitUntilRequestStarts()
        async {

        if requestStarted {
            return
        }

        await withCheckedContinuation {
            continuation in

            waiters.append(
                continuation
            )
        }
    }

    func resume(
        with network:
            WiFiNetwork?
    ) {

        continuation?
            .resume(
                returning:
                    network
            )

        continuation =
            nil
    }
}

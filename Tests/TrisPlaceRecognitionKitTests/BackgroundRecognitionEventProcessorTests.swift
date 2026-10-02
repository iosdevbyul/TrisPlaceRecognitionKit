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
    func entryDoesNotCreateVisitWhenRecognitionDoesNotConfirmPlace()
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
                store: visitStore
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

        #expect(update.events.isEmpty)
        #expect(update.startedVisits.isEmpty)

        let activeVisits =
            try await coordinator.activeVisits()

        #expect(activeVisits.isEmpty)
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
    func exitDoesNotEndVisitWhenRecognitionStillConfirmsPlace()
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
                store: visitStore
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
                .monitoredRegionExited(
                    placeID: gym.id
                ),
                at: time(120)
            )

        #expect(update.events.isEmpty)
        #expect(update.endedVisits.isEmpty)

        let activeVisits =
            try await coordinator.activeVisits()

        #expect(
            activeVisits == [
                existingVisit
            ]
        )
    }

    @Test
    func recognitionFailureDoesNotEndActiveVisit()
        async throws {

        let locationProvider =
            MockLocationProvider()

        locationProvider.requestCurrentLocationError =
            BackgroundRecognitionProcessorTestError
                .locationUnavailable

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: nil
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
                store: visitStore
            )

        _ = try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .gpsConstrained
            )

        do {

            _ = try await processor.handle(
                .monitoredRegionExited(
                    placeID: gym.id
                ),
                at: time(120)
            )

            Issue.record(
                "Expected recognition to fail."
            )

        } catch {

            // Expected.
        }

        let activeVisits =
            try await coordinator.activeVisits()

        #expect(
            activeVisits == [
                existingVisit
            ]
        )

        let events =
            try await visitStore.fetchEvents()

        #expect(events.count == 1)

        #expect(
            events.first?.kind == .arrived
        )
    }

    @Test
    func significantLocationChangeDoesNotRunVisitRecognition()
        async throws {

        let locationProvider =
            MockLocationProvider()

        locationProvider.requestCurrentLocationError =
            BackgroundRecognitionProcessorTestError
                .locationUnavailable

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

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
                store: visitStore
            )

        _ = try await coordinator.restore()

        let processor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    .gpsConstrained
            )

        let update =
            try await processor.handle(
                .significantLocationChange,
                at: time(100)
            )

        #expect(update.events.isEmpty)

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 0
        )

        #expect(
            wifiProvider
                .currentNetworkCallCount
                == 0
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

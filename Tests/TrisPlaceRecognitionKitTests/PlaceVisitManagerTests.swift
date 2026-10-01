//
//  PlaceVisitManagerTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceVisitManagerTests {

    @Test
    func startCreatesAndExposesActiveVisit() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let visitStore = InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .wifiFirst,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        try await manager.start()

        #expect(manager.isMonitoring)

        #expect(
            manager.recognizedPlaces.count == 1
        )

        #expect(
            manager.recognizedPlaces.first?.place.id
                == gym.id
        )

        #expect(
            manager.activeVisits.count == 1
        )

        #expect(
            manager.activeVisits.first?.placeID
                == gym.id
        )

        let events = try await visitStore.fetchEvents()

        #expect(events.count == 1)

        #expect(
            events.first?.kind == .arrived
        )

        manager.stop()

        #expect(!manager.isMonitoring)
    }

    @Test
    func refreshBeforeStartRestoresAutomatically() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let visitStore = InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .wifiFirst,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        try await manager.refresh()

        #expect(!manager.isMonitoring)

        #expect(
            manager.recognizedPlaces.count == 1
        )

        #expect(
            manager.activeVisits.count == 1
        )

        #expect(
            manager.activeVisits.first?.placeID
                == gym.id
        )
    }

    @Test
    func restoresExistingVisitWithoutDuplicateArrival() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let visitStore = InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let existingVisit = PlaceVisitRecord(
            placeID: gym.id,
            startedAt: time(0),
            arrivalEvidence: .ssid
        )

        let arrivalEvent = PlaceVisitEvent(
            visitID: existingVisit.id,
            placeID: gym.id,
            kind: .arrived,
            occurredAt: existingVisit.startedAt
        )

        try await visitStore.apply(
            PlaceVisitUpdate(
                events: [
                    arrivalEvent
                ],
                startedVisits: [
                    existingVisit
                ]
            )
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .wifiFirst,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 60
            )
        )

        let restored = try await manager.restore()

        #expect(
            restored == [existingVisit]
        )

        try await manager.start()

        #expect(
            manager.activeVisits == [existingVisit]
        )

        let events = try await visitStore.fetchEvents()

        #expect(events.count == 1)

        #expect(
            events.first?.visitID == existingVisit.id
        )

        manager.stop()
    }

    @Test
    func repeatedStartDoesNotRestoreOrArriveTwice() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let visitStore = InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .wifiFirst,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        try await manager.start()

        let firstVisitID = try #require(
            manager.activeVisits.first?.id
        )

        manager.stop()

        try await manager.start()

        let secondVisitID = try #require(
            manager.activeVisits.first?.id
        )

        #expect(
            firstVisitID == secondVisitID
        )

        let events = try await visitStore.fetchEvents()

        #expect(events.count == 1)

        #expect(
            events.first?.kind == .arrived
        )

        manager.stop()
    }

    @Test
    func recognitionFailureDoesNotRemoveActiveVisit() async throws {

        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = LocationPoint(
            latitude: 37.5665,
            longitude: 126.9780,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )

        let wifiProvider = MockWiFiProvider()

        let placeStore = MockPlaceStore()

        let visitStore = InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: nil
        )

        try await placeStore.save(
            gym
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .gpsConstrained,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        try await manager.start()

        #expect(
            manager.activeVisits.count == 1
        )

        let visitID = try #require(
            manager.activeVisits.first?.id
        )

        locationProvider.requestCurrentLocationError =
            PlaceVisitManagerTestError.locationUnavailable

        try await manager.refresh()

        #expect(
            manager.lastErrorMessage != nil
        )

        #expect(
            manager.recognizedPlaces.isEmpty
        )

        #expect(
            manager.activeVisits.count == 1
        )

        #expect(
            manager.activeVisits.first?.id
                == visitID
        )

        let events = try await visitStore.fetchEvents()

        #expect(events.count == 1)

        manager.stop()
    }

    @Test
    func visitPersistenceFailureKeepsRecognitionVisible() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let visitStore = FailingPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let manager = PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore,
            recognitionPolicy: .wifiFirst,
            visitPolicy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0
            )
        )

        try await manager.start()

        #expect(
            manager.recognizedPlaces.count == 1
        )

        #expect(
            manager.recognizedPlaces.first?.place.id
                == gym.id
        )

        #expect(
            manager.activeVisits.isEmpty
        )

        #expect(
            manager.lastErrorMessage == nil
        )

        #expect(
            manager.lastVisitErrorMessage != nil
        )

        manager.stop()
    }
}

private extension PlaceVisitManagerTests {

    func time(
        _ seconds: TimeInterval
    ) -> Date {

        Date(
            timeIntervalSince1970:
                1_000_000 + seconds
        )
    }

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
            networkIdentity: PlaceNetworkIdentity(
                ssid: ssid,
                bssid: nil
            )
        )
    }
}

private enum PlaceVisitManagerTestError: Error {
    case locationUnavailable
    case persistenceFailure
}

private actor FailingPlaceVisitStore:
    PlaceVisitStoring {

    func apply(
        _ update: PlaceVisitUpdate
    ) async throws {

        throw PlaceVisitManagerTestError
            .persistenceFailure
    }

    func fetchAll() async throws
        -> [PlaceVisitRecord] {

        []
    }

    func fetchActiveVisits() async throws
        -> [PlaceVisitRecord] {

        []
    }

    func fetchEvents() async throws
        -> [PlaceVisitEvent] {

        []
    }
}

//
//  PlaceRecognitionVisitIntegrationTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRecognitionVisitIntegrationTests {

    @Test
    func successfulRecognitionAutomaticallyPersistsVisits() async throws {

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

        try await placeStore.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let coordinator = PlaceVisitCoordinator(
            store: visitStore,
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        _ = try await coordinator.restore()

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .wifiFirst
        )

        monitor.onSuccessfulRecognition = {
            [coordinator] places, timestamp in

            _ = try await coordinator
                .processSuccessfulObservation(
                    places,
                    at: timestamp
                )
        }

        // First recognition: arrival.
        await monitor.refresh()

        let activeVisits = try await visitStore.fetchActiveVisits()

        #expect(activeVisits.count == 1)
        #expect(activeVisits.first?.placeID == gym.id)

        // Unchanged recognition must not generate
        // another arrival event.
        await monitor.refresh()

        let repeatedEvents = try await visitStore.fetchEvents()

        #expect(repeatedEvents.count == 1)

        // Wi-Fi disappeared. Recognition succeeds
        // with an empty matching-place result.
        wifiProvider.network = nil

        await monitor.refresh()

        let finishedVisits = try await visitStore.fetchAll()
        let finalEvents = try await visitStore.fetchEvents()

        #expect(finishedVisits.count == 1)
        #expect(finishedVisits.first?.isActive == false)

        #expect(finalEvents.count == 2)
        #expect(finalEvents.map(\.kind) == [.arrived, .departed])

        #expect(monitor.lastErrorMessage == nil)
        #expect(monitor.lastVisitErrorMessage == nil)
    }

    @Test
    func failedRecognitionDoesNotEndActiveVisit() async throws {

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

        try await placeStore.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let coordinator = PlaceVisitCoordinator(
            store: visitStore,
            policy: PlaceVisitPolicy(
                arrivalConfirmationInterval: 0,
                departureConfirmationInterval: 0
            )
        )

        _ = try await coordinator.restore()

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .gpsConstrained
        )

        monitor.onSuccessfulRecognition = {
            [coordinator] places, timestamp in

            _ = try await coordinator
                .processSuccessfulObservation(
                    places,
                    at: timestamp
                )
        }

        await monitor.refresh()

        #expect(
            try await visitStore.fetchActiveVisits().count == 1
        )

        // Simulate GPS failure.
        locationProvider.requestCurrentLocationError =
            IntegrationTestError.locationUnavailable

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.isEmpty)
        #expect(monitor.lastErrorMessage != nil)

        // GPS failure must not be interpreted
        // as a successful empty recognition.
        #expect(
            try await visitStore.fetchActiveVisits().count == 1
        )

        #expect(
            try await visitStore.fetchEvents().count == 1
        )

        monitor.stop()

        #expect(
            try await visitStore.fetchActiveVisits().count == 1
        )
    }

    @Test
    func visitPersistenceErrorDoesNotHideRecognitionResult() async throws {

        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let placeStore = MockPlaceStore()

        let gym = try makePlace(
            name: "Gym",
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .wifiFirst
        )

        monitor.onSuccessfulRecognition = { _, _ in
            throw IntegrationTestError.persistenceFailed
        }

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.count == 1)
        #expect(monitor.recognizedPlaces.first?.place.id == gym.id)

        #expect(monitor.lastErrorMessage == nil)
        #expect(monitor.lastVisitErrorMessage != nil)
    }
}

private enum IntegrationTestError: Error {
    case locationUnavailable
    case persistenceFailed
}

private extension PlaceRecognitionVisitIntegrationTests {

    func makePlace(
        name: String,
        ssid: String?
    ) throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName(name),
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

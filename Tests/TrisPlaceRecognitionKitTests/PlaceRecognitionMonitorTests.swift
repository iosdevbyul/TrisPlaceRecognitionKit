//
//  PlaceRecognitionMonitorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRecognitionMonitorTests {

    @Test
    func startRecognizesWiFiPlaceImmediately() async throws {
        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let store = MockPlaceStore()

        let gym = try makePlace(
            name: "헬스장",
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        try await store.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .wifiFirst
        )

        await monitor.start()

        #expect(monitor.isMonitoring)
        #expect(monitor.recognizedPlaces.count == 1)
        #expect(monitor.recognizedPlaces.first?.place.id == gym.id)
        #expect(monitor.recognizedPlaces.first?.evidence == .bssid)

        // A matching Wi-Fi must not trigger a GPS request.
        #expect(
            locationProvider.requestCurrentLocationCallCount == 0
        )

        monitor.stop()

        #expect(!monitor.isMonitoring)
        #expect(monitor.recognizedPlaces.isEmpty)
    }

    @Test
    func refreshRespondsToWiFiConnectionChanges() async throws {
        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let store = MockPlaceStore()

        let gym = try makePlace(
            name: "헬스장",
            ssid: "GYM_WIFI"
        )

        let home = try makePlace(
            name: "집",
            ssid: "HOME_WIFI"
        )

        try await store.save(gym)
        try await store.save(home)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .wifiFirst
        )

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.first?.place.id == gym.id)

        // Simulate connecting to a different Wi-Fi.
        wifiProvider.network = WiFiNetwork(
            ssid: "HOME_WIFI",
            bssid: nil
        )

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.count == 1)
        #expect(monitor.recognizedPlaces.first?.place.id == home.id)

        #expect(
            locationProvider.requestCurrentLocationCallCount == 0
        )
    }

    @Test
    func failedRefreshClearsPreviousRecognition() async throws {
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
        let store = MockPlaceStore()

        let park = try makePlace(name: "공원")

        try await store.save(park)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .gpsConstrained
        )

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.count == 1)
        #expect(monitor.lastErrorMessage == nil)

        locationProvider.requestCurrentLocationError =
            MonitorTestError.locationUnavailable

        await monitor.refresh()

        #expect(monitor.recognizedPlaces.isEmpty)
        #expect(monitor.lastErrorMessage != nil)
    }

    @Test
    func repeatedStartDoesNotCreateAnotherMonitor() async throws {
        let locationProvider = MockLocationProvider()

        let wifiProvider = MockWiFiProvider()

        let store = MockPlaceStore()

        let gym = try makePlace(
            name: "헬스장",
            ssid: "GYM_WIFI"
        )

        try await store.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let monitor = PlaceRecognitionMonitor(
            recognitionService: service,
            policy: .wifiFirst
        )

        await monitor.start()
        await monitor.start()

        #expect(monitor.isMonitoring)

        #expect(
            wifiProvider.currentNetworkCallCount == 1
        )

        monitor.stop()
    }
}

private enum MonitorTestError: Error {
    case locationUnavailable
}

private extension PlaceRecognitionMonitorTests {

    func makePlace(
        name: String,
        ssid: String? = nil,
        bssid: String? = nil
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
                bssid: bssid
            )
        )
    }
}

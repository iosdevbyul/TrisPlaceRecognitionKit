//
//  PlaceRecognitionServiceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRecognitionServiceTests {

    @Test
    func prioritizesBSSIDOverCloserSSIDMatch() async throws {
        let locationProvider = makeLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let store = MockPlaceStore()

        let ssidPlace = try makePlace(
            name: "SSID장소",
            latitude: 37.5665,
            ssid: "GYM_WIFI",
            bssid: "11:22:33:44:55:66"
        )

        let bssidPlace = try makePlace(
            name: "BSSID장소",
            latitude: 37.5666,
            ssid: "OTHER_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        try await store.save(ssidPlace)
        try await store.save(bssidPlace)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.count == 2)
        #expect(results.first?.place.id == bssidPlace.id)
        #expect(results.first?.evidence == .bssid)
        #expect(results.last?.evidence == .ssid)
    }

    @Test
    func prioritizesNearestPlaceWithSameEvidence() async throws {
        let locationProvider = makeLocationProvider()
        let wifiProvider = MockWiFiProvider()
        let store = MockPlaceStore()

        let distantPlace = try makePlace(
            name: "먼공원",
            latitude: 37.5667
        )

        let nearbyPlace = try makePlace(
            name: "가까운공원",
            latitude: 37.5665
        )

        try await store.save(distantPlace)
        try await store.save(nearbyPlace)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.count == 2)
        #expect(results.first?.place.id == nearbyPlace.id)
        #expect(
            results.first?.evidence == .gpsOnlyNoWiFiConfigured
        )
    }

    @Test
    func recognizesPlaceWhenWiFiIsUnavailable() async throws {
        let locationProvider = makeLocationProvider()
        let wifiProvider = MockWiFiProvider()
        let store = MockPlaceStore()

        let gym = try makePlace(
            name: "헬스장",
            latitude: 37.5665,
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        try await store.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.count == 1)
        #expect(
            results.first?.evidence == .gpsOnlyWiFiUnavailable
        )
    }

    @Test
    func excludesPlaceWithMismatchedWiFi() async throws {
        let locationProvider = makeLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "HOME_WIFI",
                bssid: "11:22:33:44:55:66"
            )
        )

        let store = MockPlaceStore()

        let gym = try makePlace(
            name: "헬스장",
            latitude: 37.5665,
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        try await store.save(gym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.isEmpty)
    }

    @Test
    func excludesPlaceOutsideGPSRadius() async throws {
        let locationProvider = makeLocationProvider()

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let store = MockPlaceStore()

        let distantGym = try makePlace(
            name: "먼헬스장",
            latitude: 37.5700,
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        try await store.save(distantGym)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.isEmpty)
    }

    @Test
    func skipsSensorRequestsWhenNoPlacesAreRegistered() async throws {
        let locationProvider = MockLocationProvider()
        let wifiProvider = MockWiFiProvider()
        let store = MockPlaceStore()

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let results = try await service.recognizeCurrentPlaces()

        #expect(results.isEmpty)
        #expect(locationProvider.requestCurrentLocationCallCount == 0)
        #expect(wifiProvider.currentNetworkCallCount == 0)
    }
}

private extension PlaceRecognitionServiceTests {

    func makeLocationProvider() -> MockLocationProvider {
        let provider = MockLocationProvider()

        provider.locationPoint = LocationPoint(
            latitude: 37.5665,
            longitude: 126.9780,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )

        return provider
    }

    func makePlace(
        name: String,
        latitude: Double,
        ssid: String? = nil,
        bssid: String? = nil
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: latitude,
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

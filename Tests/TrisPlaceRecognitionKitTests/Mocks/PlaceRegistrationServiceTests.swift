//
//  PlaceRegistrationServiceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRegistrationServiceTests {

    @Test
    func registersPlaceUsingCurrentLocationAndWiFi() async throws {
        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let placeStore = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let place = try await service.register(
            name: "헬스장"
        )

        #expect(place.name.value == "헬스장")

        #expect(
            place.location.latitude == 37.5665
        )

        #expect(
            place.location.longitude == 126.9780
        )

        #expect(
            place.location.recognitionRadius == 100
        )

        #expect(
            place.networkIdentity.ssid == "GYM_WIFI"
        )

        #expect(
            place.networkIdentity.bssid == "AA:BB:CC:DD:EE:FF"
        )
    }

    @Test
    func registersPlaceWithoutWiFi() async throws {
        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5,
            longitude: 127.0
        )

        let wifiProvider = MockWiFiProvider()

        let placeStore = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let place = try await service.register(
            name: "공원"
        )

        #expect(place.networkIdentity.ssid == nil)
        #expect(place.networkIdentity.bssid == nil)
    }

    @Test
    func usesCustomRecognitionRadius() async throws {
        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5,
            longitude: 127.0
        )

        let placeStore = MockPlaceStore()
        let wifiProvider = MockWiFiProvider()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let place = try await service.register(
            name: "공원",
            recognitionRadius: 200
        )

        #expect(
            place.location.recognitionRadius == 200
        )
    }

    @Test
    func rejectsInvalidNameBeforeRequestingLocation() async {
        let locationProvider = MockLocationProvider()
        let wifiProvider = MockWiFiProvider()

        let placeStore = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        do {
            _ = try await service.register(
                name: ""
            )

            Issue.record(
                "Expected emptyName error"
            )
        } catch let error as PlaceRegistrationError {
            #expect(error == .emptyName)
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(
            locationProvider.requestCurrentLocationCallCount == 0
        )

        #expect(
            wifiProvider.currentNetworkCallCount == 0
        )
    }
    
    @Test
    func savesRegisteredPlace() async throws {
        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let placeStore = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let place = try await service.register(
            name: "헬스장"
        )

        #expect(
            await placeStore.savedPlaceCount() == 1
        )

        #expect(
            await placeStore.lastSavedPlace() == place
        )
    }
    
    @Test
    func doesNotSaveInvalidPlaceName() async {
        let locationProvider = MockLocationProvider()
        let wifiProvider = MockWiFiProvider()
        let placeStore = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        do {
            _ = try await service.register(
                name: ""
            )

            Issue.record(
                "Expected emptyName error"
            )
        } catch let error as PlaceRegistrationError {
            #expect(error == .emptyName)
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(
            await placeStore.savedPlaceCount() == 0
        )
    }
}

private extension PlaceRegistrationServiceTests {

    func makeLocationPoint(
        latitude: Double,
        longitude: Double
    ) -> LocationPoint {
        LocationPoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )
    }
}

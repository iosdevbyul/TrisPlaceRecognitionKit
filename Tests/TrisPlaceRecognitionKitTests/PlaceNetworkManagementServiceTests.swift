//
//  PlaceNetworkManagementServiceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceNetworkManagementServiceTests {

    @Test
    func addsCurrentWiFiToGPSOnlyPlace() async throws {
        let store = MockPlaceStore()

        let place = try makePlace(
            networks: []
        )

        try await store.save(place)

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: wifiProvider
        )

        let updated = try await service.addCurrentNetwork(
            to: place.id
        )

        #expect(updated.id == place.id)
        #expect(updated.networkIdentities.count == 1)
        #expect(updated.networkIdentity.ssid == "GYM_WIFI")

        let saved = try await store.fetchAll()

        #expect(saved == [updated])
    }

    @Test
    func doesNotAddDuplicateBSSID() async throws {
        let store = MockPlaceStore()

        let place = try makePlace(
            networks: [
                PlaceNetworkIdentity(
                    ssid: "GYM_WIFI",
                    bssid: "AA:BB:CC:DD:EE:FF"
                )
            ]
        )

        try await store.save(place)

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "aa:bb:cc:dd:ee:ff"
            )
        )

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: wifiProvider
        )

        let updated = try await service.addCurrentNetwork(
            to: place.id
        )

        #expect(updated == place)
        #expect(updated.networkIdentities.count == 1)
    }

    @Test
    func allowsDifferentBSSIDWithSameSSID() async throws {
        let store = MockPlaceStore()

        let place = try makePlace(
            networks: [
                PlaceNetworkIdentity(
                    ssid: "GYM_WIFI",
                    bssid: "11:22:33:44:55:66"
                )
            ]
        )

        try await store.save(place)

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: wifiProvider
        )

        let updated = try await service.addCurrentNetwork(
            to: place.id
        )

        #expect(updated.networkIdentities.count == 2)

        #expect(
            updated.additionalNetworkIdentities.first?.bssid
                == "AA:BB:CC:DD:EE:FF"
        )
    }

    @Test
    func removingPrimaryNetworkPromotesNextNetwork() async throws {
        let store = MockPlaceStore()

        let primary = PlaceNetworkIdentity(
            ssid: "GYM_MAIN",
            bssid: "11:22:33:44:55:66"
        )

        let secondary = PlaceNetworkIdentity(
            ssid: "GYM_SECOND",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let place = try makePlace(
            networks: [primary, secondary]
        )

        try await store.save(place)

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: MockWiFiProvider()
        )

        let updated = try await service.removeNetwork(
            primary,
            from: place.id
        )

        #expect(updated.id == place.id)
        #expect(updated.location == place.location)
        #expect(updated.networkIdentity == secondary)
        #expect(updated.additionalNetworkIdentities.isEmpty)
    }

    @Test
    func removingLastNetworkMakesPlaceGPSOnly() async throws {
        let store = MockPlaceStore()

        let network = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: nil
        )

        let place = try makePlace(
            networks: [network]
        )

        try await store.save(place)

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: MockWiFiProvider()
        )

        let updated = try await service.removeNetwork(
            network,
            from: place.id
        )

        #expect(updated.networkIdentities.isEmpty)
        #expect(updated.id == place.id)

        let saved = try await store.fetchAll()

        #expect(saved == [updated])
    }

    @Test
    func rejectsAddingNetworkWhenWiFiUnavailable() async throws {
        let store = MockPlaceStore()
        let place = try makePlace(networks: [])

        try await store.save(place)

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: MockWiFiProvider()
        )

        do {
            _ = try await service.addCurrentNetwork(
                to: place.id
            )

            Issue.record("Expected Wi-Fi unavailable error")
        } catch let error as PlaceNetworkManagementError {
            #expect(error == .currentWiFiUnavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(try await store.fetchAll() == [place])
    }

    @Test
    func rejectsAddingNetworkToUnknownPlace() async {
        let store = MockPlaceStore()
        let wifiProvider = MockWiFiProvider()

        let service = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: wifiProvider
        )

        let unknownID = UUID()

        do {
            _ = try await service.addCurrentNetwork(
                to: unknownID
            )

            Issue.record("Expected place not found error")
        } catch let error as PlaceNetworkManagementError {
            #expect(error == .placeNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(wifiProvider.currentNetworkCallCount == 0)
    }
}

private extension PlaceNetworkManagementServiceTests {

    func makePlace(
        networks: [PlaceNetworkIdentity]
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: networks.first
                ?? PlaceNetworkIdentity(
                    ssid: nil,
                    bssid: nil
                ),
            additionalNetworkIdentities: Array(
                networks.dropFirst()
            )
        )
    }
}

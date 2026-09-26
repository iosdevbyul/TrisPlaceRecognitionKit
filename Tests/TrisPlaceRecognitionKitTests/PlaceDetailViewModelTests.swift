//
//  PlaceDetailViewModelTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceDetailViewModelTests {

    @Test
    func updatesNameAndRadiusWithoutLosingNetworks() async throws {
        let fixture = try await makeFixture()
        let viewModel = fixture.viewModel

        viewModel.name = "회사헬스장"

        await viewModel.rename()

        #expect(viewModel.place.name.value == "회사헬스장")
        #expect(viewModel.place.id == fixture.original.id)

        viewModel.recognitionRadius = 200

        await viewModel.updateRadius()

        #expect(
            viewModel.place.location.recognitionRadius == 200
        )

        #expect(
            viewModel.place.networkIdentities
                == fixture.original.networkIdentities
        )

        let saved = try await fixture.store.fetchAll()

        #expect(saved == [viewModel.place])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func addsAndRemovesWiFiWithoutChangingPlaceIdentity() async throws {
        let fixture = try await makeFixture(
            wifi: WiFiNetwork(
                ssid: "GYM_SECOND",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let viewModel = fixture.viewModel

        await viewModel.addCurrentWiFi()

        #expect(viewModel.place.networkIdentities.count == 2)
        #expect(viewModel.place.id == fixture.original.id)

        // Removing the primary network should promote
        // the newly added network.
        await viewModel.removeNetwork(
            fixture.original.networkIdentity
        )

        #expect(viewModel.place.networkIdentities.count == 1)

        #expect(
            viewModel.place.networkIdentity.ssid
                == "GYM_SECOND"
        )

        #expect(viewModel.place.id == fixture.original.id)

        let saved = try await fixture.store.fetchAll()

        #expect(saved == [viewModel.place])
    }

    @Test
    func updatesCurrentLocation() async throws {
        let fixture = try await makeFixture()
        let viewModel = fixture.viewModel

        await viewModel.updateCurrentLocation()

        #expect(viewModel.place.location.latitude == 37.5700)
        #expect(viewModel.place.location.longitude == 127.0000)

        #expect(
            viewModel.place.location.recognitionRadius == 100
        )

        #expect(
            viewModel.place.networkIdentities
                == fixture.original.networkIdentities
        )

        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func unavailableWiFiDoesNotChangeSavedPlace() async throws {
        let fixture = try await makeFixture()
        let viewModel = fixture.viewModel

        await viewModel.addCurrentWiFi()

        #expect(viewModel.place == fixture.original)
        #expect(viewModel.errorMessage != nil)

        let saved = try await fixture.store.fetchAll()

        #expect(saved == [fixture.original])
    }

    @Test
    func deletesPlaceAndReportsCompletion() async throws {
        let fixture = try await makeFixture()
        let viewModel = fixture.viewModel

        await viewModel.deletePlace()

        #expect(viewModel.didDelete)
        #expect(viewModel.errorMessage == nil)

        let remaining = try await fixture.store.fetchAll()

        #expect(remaining.isEmpty)
    }
}

private extension PlaceDetailViewModelTests {

    func makeFixture(
        wifi: WiFiNetwork? = nil
    ) async throws -> (
        viewModel: PlaceDetailViewModel,
        store: MockPlaceStore,
        original: RegisteredPlace
    ) {
        let store = MockPlaceStore()

        let original = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_MAIN",
                bssid: "11:22:33:44:55:66"
            )
        )

        try await store.save(original)

        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = LocationPoint(
            latitude: 37.5700,
            longitude: 127.0000,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )

        let wifiProvider = MockWiFiProvider(
            network: wifi
        )

        let managementService = PlaceManagementService(
            placeStore: store,
            locationProvider: locationProvider
        )

        let networkManagementService =
            PlaceNetworkManagementService(
                placeStore: store,
                wifiProvider: wifiProvider
            )

        let viewModel = PlaceDetailViewModel(
            place: original,
            managementService: managementService,
            networkManagementService: networkManagementService
        )

        return (
            viewModel,
            store,
            original
        )
    }
}

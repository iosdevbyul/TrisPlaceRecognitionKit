//
//  PlaceManagementFlowTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceManagementFlowTests {

    @Test
    func registeredPlaceAppearsAfterListRefresh() async throws {
        let store = InMemoryPlaceStore()

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

        let registrationService = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: MockWiFiProvider(),
            placeStore: store
        )

        let duplicateCheckService = PlaceDuplicateCheckService(
            placeStore: store
        )

        let listViewModel = PlaceListViewModel(
            placeStore: store
        )

        // Initially, the list is empty.
        await listViewModel.load()

        #expect(listViewModel.places.isEmpty)

        // Prepare a new place.
        let candidate = try await registrationService
            .prepareRegistration(
                name: "헬스장",
                method: .gpsOnly
            )

        let warnings = try await duplicateCheckService
            .check(candidate: candidate)

        #expect(warnings.isEmpty)

        // Save the approved candidate.
        let saved = try await registrationService
            .savePrepared(candidate)

        // Refresh the list after registration.
        await listViewModel.load()

        #expect(listViewModel.places == [saved])
        #expect(listViewModel.errorMessage == nil)
    }
    
    @Test
    func editingAndDeletingRefreshesPlaceList() async throws {
        let store = InMemoryPlaceStore()

        let original = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        try await store.save(original)

        let managementService = PlaceManagementService(
            placeStore: store,
            locationProvider: MockLocationProvider()
        )

        let listViewModel = PlaceListViewModel(
            placeStore: store
        )

        // Load the original place.
        await listViewModel.load()

        #expect(listViewModel.places == [original])

        // Edit the place.
        let renamed = try await managementService.renamePlace(
            id: original.id,
            to: "회사헬스장"
        )

        // Refresh the list.
        await listViewModel.load()

        #expect(listViewModel.places == [renamed])

        #expect(
            listViewModel.places.first?.id == original.id
        )

        // Delete the same place.
        try await managementService.deletePlace(
            id: original.id
        )

        // Refresh the list again.
        await listViewModel.load()

        #expect(listViewModel.places.isEmpty)
        #expect(listViewModel.errorMessage == nil)
    }
}

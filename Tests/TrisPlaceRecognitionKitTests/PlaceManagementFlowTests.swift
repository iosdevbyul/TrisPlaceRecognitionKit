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
}

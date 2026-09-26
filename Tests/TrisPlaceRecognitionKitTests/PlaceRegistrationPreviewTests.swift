//
//  PlaceRegistrationPreviewTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRegistrationPreviewTests {

    @Test
    func detectsDuplicatesBeforeSavingCandidate() async throws {
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

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let placeStore = MockPlaceStore()

        let existing = RegisteredPlace(
            name: try PlaceName("기존 헬스장"),
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

        try await placeStore.save(existing)

        let registrationService = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let duplicateCheckService = PlaceDuplicateCheckService(
            placeStore: placeStore
        )

        // Preparing a candidate must not save it.
        let candidate = try await registrationService
            .prepareRegistration(
                name: "새 헬스장",
                method: .wifi
            )

        #expect(candidate.name.value == "새 헬스장")
        #expect(candidate.networkIdentity.ssid == "GYM_WIFI")
        #expect(await placeStore.savedPlaceCount() == 1)

        // Check duplicates before asking for confirmation.
        let warnings = try await duplicateCheckService
            .check(candidate: candidate)

        #expect(warnings.count == 1)
        #expect(warnings.first?.existingPlace.id == existing.id)

        #expect(
            warnings.first?.reasons.contains(.sameBSSID)
                == true
        )

        #expect(await placeStore.savedPlaceCount() == 1)

        // Simulate the user approving registration.
        let saved = try await registrationService
            .savePrepared(candidate)

        #expect(saved.id == candidate.id)
        #expect(await placeStore.savedPlaceCount() == 2)
        #expect(await placeStore.lastSavedPlace() == candidate)
    }

    @Test
    func cancellingPreviewLeavesStoreUnchanged() async throws {
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

        let placeStore = MockPlaceStore()

        let registrationService = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: MockWiFiProvider(),
            placeStore: placeStore
        )

        // Simulate opening and then cancelling the preview.
        _ = try await registrationService.prepareRegistration(
            name: "헬스장",
            method: .gpsOnly
        )

        // No savePrepared() call occurs.
        #expect(await placeStore.savedPlaceCount() == 0)
    }
}

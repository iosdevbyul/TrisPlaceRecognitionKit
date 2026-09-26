//
//  PlaceRegistrationViewModelTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRegistrationViewModelTests {

    @Test
    func previewDoesNotSavePlace() async throws {
        let store = MockPlaceStore()
        let viewModel = makeViewModel(store: store)

        viewModel.name = "헬스장"
        viewModel.method = .gpsOnly

        await viewModel.prepare()

        #expect(viewModel.phase == .reviewing)
        #expect(viewModel.candidate != nil)
        #expect(viewModel.warnings.isEmpty)
        #expect(await store.savedPlaceCount() == 0)
    }

    @Test
    func confirmationSavesPreparedCandidate() async throws {
        let store = MockPlaceStore()
        let viewModel = makeViewModel(store: store)

        viewModel.name = "헬스장"

        await viewModel.prepare()

        let candidate = try #require(viewModel.candidate)

        await viewModel.confirmRegistration()

        #expect(viewModel.phase == .completed)
        #expect(viewModel.registeredPlace?.id == candidate.id)
        #expect(await store.lastSavedPlace() == candidate)
        #expect(await store.savedPlaceCount() == 1)
    }

    @Test
    func cancellationDoesNotSavePlace() async {
        let store = MockPlaceStore()
        let viewModel = makeViewModel(store: store)

        viewModel.name = "헬스장"

        await viewModel.prepare()

        viewModel.cancelPreview()

        #expect(viewModel.phase == .editing)
        #expect(viewModel.candidate == nil)
        #expect(await store.savedPlaceCount() == 0)
    }

    @Test
    func newDuplicateRequiresAnotherConfirmation() async throws {
        let store = MockPlaceStore()
        let viewModel = makeViewModel(store: store)

        viewModel.name = "헬스장"

        await viewModel.prepare()

        #expect(viewModel.warnings.isEmpty)

        let otherPlace = RegisteredPlace(
            name: try PlaceName("기존 헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )

        try await store.save(otherPlace)

        // First confirmation discovers the new overlap.
        await viewModel.confirmRegistration()

        #expect(viewModel.phase == .reviewing)
        #expect(viewModel.warnings.count == 1)
        #expect(await store.savedPlaceCount() == 1)

        // Second confirmation approves the updated warning.
        await viewModel.confirmRegistration()

        #expect(viewModel.phase == .completed)
        #expect(await store.savedPlaceCount() == 2)
    }
}

private extension PlaceRegistrationViewModelTests {

    func makeViewModel(
        store: MockPlaceStore
    ) -> PlaceRegistrationViewModel {
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

        let registrationService = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let duplicateCheckService = PlaceDuplicateCheckService(
            placeStore: store
        )

        return PlaceRegistrationViewModel(
            registrationService: registrationService,
            duplicateCheckService: duplicateCheckService
        )
    }
}

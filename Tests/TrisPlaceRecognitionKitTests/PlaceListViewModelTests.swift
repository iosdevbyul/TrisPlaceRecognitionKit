//
//  PlaceListViewModelTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceListViewModelTests {

    @Test
    func loadsRegisteredPlacesInNameOrder() async throws {
        let store = InMemoryPlaceStore()

        let gym = try makePlace(name: "헬스장")
        let office = try makePlace(name: "회사")

        try await store.save(gym)
        try await store.save(office)

        let viewModel = PlaceListViewModel(
            placeStore: store
        )

        await viewModel.load()

        #expect(viewModel.places == [gym, office])
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func loadsEmptyStore() async {
        let viewModel = PlaceListViewModel(
            placeStore: InMemoryPlaceStore()
        )

        await viewModel.load()

        #expect(viewModel.places.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func refreshesAfterPlaceIsAdded() async throws {
        let store = InMemoryPlaceStore()

        let viewModel = PlaceListViewModel(
            placeStore: store
        )

        await viewModel.load()

        #expect(viewModel.places.isEmpty)

        let gym = try makePlace(name: "헬스장")

        try await store.save(gym)

        await viewModel.load()

        #expect(viewModel.places == [gym])
    }
}

private extension PlaceListViewModelTests {

    func makePlace(
        name: String
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            name: try PlaceName(name),
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
    }
}

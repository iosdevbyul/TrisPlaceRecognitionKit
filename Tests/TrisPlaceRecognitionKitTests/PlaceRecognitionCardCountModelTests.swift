//
//  PlaceRecognitionCardCountModelTests.swift
//  TrisPlaceRecognitionKitTests
//
//  Created by COMATOKI on 2026-10-07.
//

import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRecognitionCardCountModelTests {
    @Test
    func countsAllRegisteredPlacesEvenWhenNotRecognized() async throws {
        let store = InMemoryPlaceStore()
        let model = PlaceRecognitionCardCountModel()

        let first = try makePlace(name: "회사헬스장")
        let second = try makePlace(name: "집헬스장")

        try await store.save(first)
        try await store.save(second)
        await model.reload(placeStore: store)

        #expect(model.count == 2)
    }

    @Test
    func reloadReflectsRegistrationAndDeletion() async throws {
        let store = InMemoryPlaceStore()
        let model = PlaceRecognitionCardCountModel()

        await model.reload(placeStore: store)
        #expect(model.count == 0)

        let first = try makePlace(name: "회사헬스장")
        let second = try makePlace(name: "집헬스장")
        try await store.save(first)
        try await store.save(second)
        await model.reload(placeStore: store)
        #expect(model.count == 2)

        try await store.delete(id: first.id)
        await model.reload(placeStore: store)
        #expect(model.count == 1)
    }

    @Test
    func doesNotShowStaleCountWhenStoreIsUnavailable() async throws {
        let store = InMemoryPlaceStore()
        let model = PlaceRecognitionCardCountModel()

        try await store.save(makePlace(name: "헬스장"))
        await model.reload(placeStore: store)
        #expect(model.count == 1)

        await model.reload(placeStore: nil)
        #expect(model.count == nil)
    }

    private func makePlace(name: String) throws -> RegisteredPlace {
        RegisteredPlace(
            name: try PlaceName(name),
            location: nil,
            networkIdentity: PlaceNetworkIdentity(ssid: nil, bssid: nil)
        )
    }
}

//
//  InMemoryPlaceStoreTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-23.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct InMemoryPlaceStoreTests {

    @Test
    func initiallyContainsNoPlaces() async throws {
        let store = InMemoryPlaceStore()

        let places = try await store.fetchAll()

        #expect(places.isEmpty)
    }

    @Test
    func savesAndFetchesPlace() async throws {
        let store = InMemoryPlaceStore()

        let place = try makePlace(
            name: "헬스장"
        )

        try await store.save(place)

        let places = try await store.fetchAll()

        #expect(places == [place])
    }

    @Test
    func updatesExistingPlaceWithSameID() async throws {
        let store = InMemoryPlaceStore()

        let id = UUID()

        let original = try makePlace(
            id: id,
            name: "헬스장"
        )

        let updated = try makePlace(
            id: id,
            name: "회사헬스장"
        )

        try await store.save(original)
        try await store.save(updated)

        let places = try await store.fetchAll()

        #expect(places.count == 1)
        #expect(places.first == updated)
    }

    @Test
    func deletesRegisteredPlace() async throws {
        let store = InMemoryPlaceStore()

        let gym = try makePlace(
            name: "헬스장"
        )

        let park = try makePlace(
            name: "공원"
        )

        try await store.save(gym)
        try await store.save(park)

        try await store.delete(
            id: gym.id
        )

        let places = try await store.fetchAll()

        #expect(places == [park])
    }

    @Test
    func deletingUnknownPlaceDoesNothing() async throws {
        let store = InMemoryPlaceStore()

        let place = try makePlace()

        try await store.save(place)

        try await store.delete(
            id: UUID()
        )

        let places = try await store.fetchAll()

        #expect(places == [place])
    }
}

private extension InMemoryPlaceStoreTests {

    func makePlace(
        id: UUID = UUID(),
        name: String = "헬스장"
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            id: id,
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

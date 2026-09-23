//
//  SwiftDataPlaceStoreTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

struct SwiftDataPlaceStoreTests {
    @available(iOS 17.0, *)
    @Test
    func initiallyContainsNoPlaces() async throws {
        let store = try makeStore()

        let places = try await store.fetchAll()

        #expect(
            places.isEmpty
        )
    }
    @available(iOS 17.0, *)
    @Test
    func savesAndFetchesPlace() async throws {
        let store = try makeStore()

        let place = try makePlace(
            name: "헬스장"
        )

        try await store.save(
            place
        )

        let places = try await store.fetchAll()

        #expect(
            places == [place]
        )
    }
    @available(iOS 17.0, *)
    @Test
    func updatesExistingPlaceWithSameID() async throws {
        let store = try makeStore()

        let id = UUID()

        let original = try makePlace(
            id: id,
            name: "헬스장"
        )

        let updated = try makePlace(
            id: id,
            name: "회사헬스장"
        )

        try await store.save(
            original
        )

        try await store.save(
            updated
        )

        let places = try await store.fetchAll()

        #expect(
            places.count == 1
        )

        #expect(
            places.first == updated
        )
    }
    @available(iOS 17.0, *)
    @Test
    func deletesRegisteredPlace() async throws {
        let store = try makeStore()

        let gym = try makePlace(
            name: "헬스장"
        )

        let park = try makePlace(
            name: "공원"
        )

        try await store.save(
            gym
        )

        try await store.save(
            park
        )

        try await store.delete(
            id: gym.id
        )

        let places = try await store.fetchAll()

        #expect(
            places == [park]
        )
    }
    @available(iOS 17.0, *)
    @Test
    func deletingUnknownPlaceDoesNothing() async throws {
        let store = try makeStore()

        let place = try makePlace(
            name: "헬스장"
        )

        try await store.save(
            place
        )

        try await store.delete(
            id: UUID()
        )

        let places = try await store.fetchAll()

        #expect(
            places == [place]
        )
    }
}

@available(iOS 17.0, *)
private extension SwiftDataPlaceStoreTests {

    func makeStore() throws -> SwiftDataPlaceStore {
        let schema = Schema([
            SwiftDataPlaceModel.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: [
                configuration
            ]
        )

        return SwiftDataPlaceStore(
            modelContainer: container
        )
    }

    func makePlace(
        id: UUID = UUID(),
        name: String
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            id: id,
            name: try PlaceName(
                name
            ),
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
    }
}

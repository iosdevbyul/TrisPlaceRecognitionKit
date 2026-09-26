//
//  PlaceManagementServiceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceManagementServiceTests {

    @Test
    func renamesPlaceWithoutChangingOtherProperties() async throws {
        let store = MockPlaceStore()
        let original = try makePlace(name: "헬스장")

        try await store.save(original)

        let service = makeService(store: store)

        let updated = try await service.renamePlace(
            id: original.id,
            to: "회사헬스장"
        )

        #expect(updated.id == original.id)
        #expect(updated.name.value == "회사헬스장")
        #expect(updated.location == original.location)
        #expect(
            updated.networkIdentities == original.networkIdentities
        )

        let saved = try await store.fetchAll()
        #expect(saved == [updated])
    }

    @Test
    func updatesRecognitionRadiusWithoutChangingCoordinates() async throws {
        let store = MockPlaceStore()
        let original = try makePlace(name: "헬스장")

        try await store.save(original)

        let service = makeService(store: store)

        let updated = try await service.updateRecognitionRadius(
            for: original.id,
            to: 200
        )

        #expect(updated.id == original.id)
        #expect(updated.location.recognitionRadius == 200)
        #expect(
            updated.location.latitude == original.location.latitude
        )
        #expect(
            updated.location.longitude == original.location.longitude
        )
        #expect(
            updated.networkIdentities == original.networkIdentities
        )
    }

    @Test
    func rejectsInvalidRadiusWithoutChangingStoredPlace() async throws {
        let store = MockPlaceStore()
        let original = try makePlace(name: "헬스장")

        try await store.save(original)

        let service = makeService(store: store)

        do {
            _ = try await service.updateRecognitionRadius(
                for: original.id,
                to: -10
            )

            Issue.record("Expected invalid radius error")
        } catch let error as PlaceManagementError {
            #expect(error == .invalidRecognitionRadius)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let saved = try await store.fetchAll()
        #expect(saved == [original])
    }

    @Test
    func updatesCurrentLocationWhilePreservingNetworks() async throws {
        let store = MockPlaceStore()
        let original = try makePlace(name: "헬스장")

        try await store.save(original)

        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5700,
            longitude: 127.0000
        )

        let service = makeService(
            store: store,
            locationProvider: locationProvider
        )

        let updated = try await service.updateCurrentLocation(
            for: original.id
        )

        #expect(updated.location.latitude == 37.5700)
        #expect(updated.location.longitude == 127.0000)

        #expect(
            updated.location.recognitionRadius
                == original.location.recognitionRadius
        )

        #expect(
            updated.networkIdentities == original.networkIdentities
        )

        #expect(
            locationProvider.requestCurrentLocationCallCount == 1
        )
    }

    @Test
    func rejectsInaccurateLocationWithoutOverwritingOldLocation() async throws {
        let store = MockPlaceStore()
        let original = try makePlace(name: "헬스장")

        try await store.save(original)

        let locationProvider = MockLocationProvider()

        locationProvider.locationPoint = makeLocationPoint(
            latitude: 37.5700,
            longitude: 127.0000,
            accuracy: 300
        )

        let service = makeService(
            store: store,
            locationProvider: locationProvider
        )

        do {
            _ = try await service.updateCurrentLocation(
                for: original.id
            )

            Issue.record("Expected invalid location error")
        } catch let error as PlaceManagementError {
            #expect(error == .invalidCurrentLocation)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let saved = try await store.fetchAll()
        #expect(saved == [original])
    }

    @Test
    func deletesOnlyRequestedPlace() async throws {
        let store = MockPlaceStore()

        let gym = try makePlace(name: "헬스장")
        let park = try makePlace(name: "공원")

        try await store.save(gym)
        try await store.save(park)

        let service = makeService(store: store)

        try await service.deletePlace(id: gym.id)

        let remaining = try await store.fetchAll()

        #expect(remaining == [park])
    }

    @Test
    func rejectsDeletingUnknownPlace() async {
        let store = MockPlaceStore()
        let service = makeService(store: store)

        let unknownID = UUID()

        do {
            try await service.deletePlace(id: unknownID)

            Issue.record("Expected place not found error")
        } catch let error as PlaceManagementError {
            #expect(error == .placeNotFound(unknownID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private extension PlaceManagementServiceTests {

    func makeService(
        store: MockPlaceStore,
        locationProvider: MockLocationProvider =
            MockLocationProvider()
    ) -> PlaceManagementService {
        PlaceManagementService(
            placeStore: store,
            locationProvider: locationProvider
        )
    }

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
                ssid: "GYM_MAIN",
                bssid: "11:22:33:44:55:66"
            ),
            additionalNetworkIdentities: [
                PlaceNetworkIdentity(
                    ssid: "GYM_SECOND",
                    bssid: "AA:BB:CC:DD:EE:FF"
                )
            ]
        )
    }

    func makeLocationPoint(
        latitude: Double,
        longitude: Double,
        accuracy: Double = 5
    ) -> LocationPoint {
        LocationPoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )
    }
}

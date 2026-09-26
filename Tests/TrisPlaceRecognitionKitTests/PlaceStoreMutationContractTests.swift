//
//  PlaceStoreMutationContractTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//


import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceStoreMutationContractTests {

    @Test
    func fileStorePreservesConcurrentUpdates() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        let fileURL = directoryURL
            .appendingPathComponent("registered-places.json")

        defer {
            try? FileManager.default.removeItem(
                at: directoryURL
            )
        }

        let store = FilePlaceStore(fileURL: fileURL)

        try await verifyUpdateContract(
            using: store
        )

        // Reopen the file to ensure the final result
        // was persisted rather than only kept in memory.
        let reopenedStore = FilePlaceStore(
            fileURL: fileURL
        )

        let restored = try await reopenedStore.fetchAll()

        #expect(restored.count == 1)
        #expect(restored.first?.name.value == "회사헬스장")
        #expect(restored.first?.networkIdentities.count == 2)
    }

    @Test
    func swiftDataStorePreservesConcurrentUpdates() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let schema = Schema([
            SwiftDataPlaceModel.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        let store = SwiftDataPlaceStore(
            modelContainer: container
        )

        try await verifyUpdateContract(
            using: store
        )
    }
}

private extension PlaceStoreMutationContractTests {

    func verifyUpdateContract(
        using store: any PlaceStoring
    ) async throws {
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

        // Both tasks update the same place.
        // Their execution order is intentionally unspecified.
        async let rename = store.update(
            id: original.id
        ) { place in
            var updated = place
            updated.name = try PlaceName("회사헬스장")
            return updated
        }

        async let addNetwork = store.update(
            id: original.id
        ) { place in
            let additional = PlaceNetworkIdentity(
                ssid: "GYM_SECOND",
                bssid: "AA:BB:CC:DD:EE:FF"
            )

            return RegisteredPlace(
                id: place.id,
                name: place.name,
                location: place.location,
                networkIdentity: place.networkIdentity,
                additionalNetworkIdentities:
                    place.additionalNetworkIdentities
                    + [additional]
            )
        }

        _ = try await (rename, addNetwork)

        let places = try await store.fetchAll()

        let saved = try #require(
            places.first
        )

        // Both modifications must survive regardless
        // of which update executes first.
        #expect(places.count == 1)
        #expect(saved.id == original.id)
        #expect(saved.name.value == "회사헬스장")
        #expect(saved.networkIdentities.count == 2)

        #expect(
            saved.additionalNetworkIdentities.first?.ssid
                == "GYM_SECOND"
        )

        // An update must never change a place's identity.
        do {
            _ = try await store.update(
                id: original.id
            ) { place in
                RegisteredPlace(
                    id: UUID(),
                    name: place.name,
                    location: place.location,
                    networkIdentity: place.networkIdentity,
                    additionalNetworkIdentities:
                        place.additionalNetworkIdentities
                )
            }

            Issue.record(
                "Expected identifierChanged error"
            )
        } catch let error as PlaceMutationError {
            #expect(error == .identifierChanged)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // A rejected update must preserve the data.
        let afterRejectedUpdate = try await store.fetchAll()

        #expect(afterRejectedUpdate == [saved])

        // Updating a nonexistent place must not
        // accidentally create a new place.
        let missingResult = try await store.update(
            id: UUID()
        ) { place in
            place
        }

        #expect(missingResult == nil)
        #expect(try await store.fetchAll() == [saved])
    }
}

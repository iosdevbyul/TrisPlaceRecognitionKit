//
//  PlaceStoreFactoryTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceStoreFactoryTests {

    @Test
    func createsSwiftDataStoreWithoutLegacyFile() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let targetStore = try makeSwiftDataStore()

        let store = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        #expect(store is SwiftDataPlaceStore)

        let places = try await store.fetchAll()

        #expect(places.isEmpty)
    }

    @Test
    func automaticallyMigratesLegacyPlaces() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let gym = try makePlace(name: "헬스장")
        let park = try makePlace(name: "공원")

        let originalPlaces = [gym, park]

        try writePlaces(
            originalPlaces,
            to: fileURL
        )

        let originalData = try Data(
            contentsOf: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        let store = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        let restoredPlaces = try await store.fetchAll()

        #expect(restoredPlaces.count == 2)

        #expect(
            Set(restoredPlaces) == Set(originalPlaces)
        )

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == originalData)

        let markerURL = LegacyPlaceMigrator.markerURL(
            for: fileURL
        )

        #expect(
            FileManager.default.fileExists(
                atPath: markerURL.path
            )
        )
    }

    @Test
    func corruptedLegacyFilePreventsStoreCreation() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let corruptedData = Data(
            "invalid JSON".utf8
        )

        try writeRawData(
            corruptedData,
            to: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        do {
            _ = try await PlaceStoreFactory.makeStore(
                legacyFileURL: fileURL,
                swiftDataStore: targetStore
            )

            Issue.record("Expected decoding failure")
        } catch is DecodingError {
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        let places = try await targetStore.fetchAll()

        #expect(places.isEmpty)

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == corruptedData)

        let markerURL = LegacyPlaceMigrator.markerURL(
            for: fileURL
        )

        #expect(
            !FileManager.default.fileExists(
                atPath: markerURL.path
            )
        )
    }

    @Test
    func conflictingPlacePreventsMigration() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let id = UUID()

        let legacyPlace = try makePlace(
            id: id,
            name: "헬스장"
        )

        let existingPlace = try makePlace(
            id: id,
            name: "공원"
        )

        try writePlaces(
            [legacyPlace],
            to: fileURL
        )

        let originalData = try Data(
            contentsOf: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        try await targetStore.save(existingPlace)

        do {
            _ = try await PlaceStoreFactory.makeStore(
                legacyFileURL: fileURL,
                swiftDataStore: targetStore
            )

            Issue.record(
                "Expected conflictingExistingPlace error"
            )
        } catch let error as PlaceMigrationError {
            #expect(
                error == .conflictingExistingPlace(id)
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        let places = try await targetStore.fetchAll()

        #expect(places == [existingPlace])

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == originalData)

        let markerURL = LegacyPlaceMigrator.markerURL(
            for: fileURL
        )

        #expect(
            !FileManager.default.fileExists(
                atPath: markerURL.path
            )
        )
    }

    @Test
    func repeatedStoreCreationDoesNotDuplicatePlaces() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let place = try makePlace(
            name: "헬스장"
        )

        try writePlaces(
            [place],
            to: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        let firstStore = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        let firstResult = try await firstStore.fetchAll()

        #expect(firstResult == [place])

        let secondStore = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        let secondResult = try await secondStore.fetchAll()

        #expect(secondResult.count == 1)
        #expect(secondResult.first == place)
    }

    @Test
    func detectsLegacyFileChangesAfterMigration() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let gym = try makePlace(
            name: "헬스장"
        )

        try writePlaces(
            [gym],
            to: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        _ = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        let park = try makePlace(
            name: "공원"
        )

        try writePlaces(
            [gym, park],
            to: fileURL
        )

        do {
            _ = try await PlaceStoreFactory.makeStore(
                legacyFileURL: fileURL,
                swiftDataStore: targetStore
            )

            Issue.record(
                "Expected legacyFileChanged error"
            )
        } catch let error as PlaceMigrationError {
            #expect(
                error == .legacyFileChanged
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        let places = try await targetStore.fetchAll()

        #expect(places == [gym])
    }
}

private extension PlaceStoreFactoryTests {

    func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
            .appendingPathComponent(
                "registered-places.json"
            )
    }

    func removeTemporaryDirectory(
        for fileURL: URL
    ) {
        try? FileManager.default.removeItem(
            at: fileURL.deletingLastPathComponent()
        )
    }

    func writePlaces(
        _ places: [RegisteredPlace],
        to fileURL: URL
    ) throws {
        let data = try JSONEncoder().encode(
            places
        )

        try writeRawData(
            data,
            to: fileURL
        )
    }

    func writeRawData(
        _ data: Data,
        to fileURL: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try data.write(
            to: fileURL,
            options: .atomic
        )
    }

    func makePlace(
        id: UUID = UUID(),
        name: String
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
    
    
    @Test
    func restoresPlacesWhenSwiftDataWasReset() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let gym = try makePlace(name: "헬스장")

        try writePlaces(
            [gym],
            to: fileURL
        )

        let originalStore = try makeSwiftDataStore()

        _ = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: originalStore
        )

        // Simulate a lost SwiftData database.
        // The legacy JSON and its marker still exist.
        let resetStore = try makeSwiftDataStore()

        let restoredStore = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: resetStore
        )

        let restoredPlaces = try await restoredStore.fetchAll()

        #expect(restoredPlaces == [gym])
    }

    @Test
    func doesNotRestoreIntentionallyDeletedPlaces() async throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let gym = try makePlace(name: "헬스장")

        try writePlaces(
            [gym],
            to: fileURL
        )

        let targetStore = try makeSwiftDataStore()

        let store = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        try await store.delete(id: gym.id)

        let reopenedStore = try await PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL,
            swiftDataStore: targetStore
        )

        let places = try await reopenedStore.fetchAll()

        #expect(places.isEmpty)
    }
}

@available(iOS 17.0, *)
private extension PlaceStoreFactoryTests {

    func makeSwiftDataStore() throws -> SwiftDataPlaceStore {
        let schema = Schema([
            SwiftDataPlaceModel.self,
            SwiftDataPlaceMigrationReceipt.self
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
}

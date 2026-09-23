//
//  FilePlaceStoreTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct FilePlaceStoreTests {

    @Test
    func returnsEmptyArrayWhenFileDoesNotExist() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let store = FilePlaceStore(fileURL: fileURL)

        let places = try await store.fetchAll()

        #expect(places.isEmpty)
    }

    @Test
    func persistsPlacesAcrossStoreInstances() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let firstStore = FilePlaceStore(
            fileURL: fileURL
        )

        let place = try makePlace(
            name: "헬스장"
        )

        try await firstStore.save(place)

        let secondStore = FilePlaceStore(
            fileURL: fileURL
        )

        let restoredPlaces = try await secondStore.fetchAll()

        #expect(restoredPlaces == [place])

        #expect(
            FileManager.default.fileExists(
                atPath: fileURL.path
            )
        )
    }

    @Test
    func updatesPlaceWithSameID() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let store = FilePlaceStore(fileURL: fileURL)
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

        #expect(places == [updated])
    }

    @Test
    func deletesOnlyRequestedPlace() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let store = FilePlaceStore(fileURL: fileURL)

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

        let reopenedStore = FilePlaceStore(
            fileURL: fileURL
        )

        let places = try await reopenedStore.fetchAll()

        #expect(places == [park])
    }

    @Test
    func doesNotOverwriteCorruptedFile() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let store = FilePlaceStore(fileURL: fileURL)

        try await store.save(
            makePlace(name: "헬스장")
        )

        let corruptedData = Data(
            "invalid JSON".utf8
        )

        try corruptedData.write(
            to: fileURL,
            options: .atomic
        )

        do {
            _ = try await store.fetchAll()

            Issue.record(
                "Expected decoding failure"
            )
        } catch is DecodingError {
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        do {
            try await store.save(
                makePlace(name: "공원")
            )

            Issue.record(
                "Expected save to fail"
            )
        } catch is DecodingError {
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == corruptedData)
    }

    @Test
    func preservesExistingFileWhenEncodingFails() async throws {
        let fileURL = makeTemporaryFileURL()

        defer {
            removeTemporaryDirectory(for: fileURL)
        }

        let store = FilePlaceStore(fileURL: fileURL)

        let original = try makePlace(
            name: "헬스장"
        )

        try await store.save(original)

        let originalData = try Data(
            contentsOf: fileURL
        )

        let invalidPlace = try makePlace(
            name: "공원",
            recognitionRadius: .infinity
        )

        do {
            try await store.save(invalidPlace)

            Issue.record(
                "Expected encoding failure"
            )
        } catch is EncodingError {
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == originalData)

        let places = try await store.fetchAll()

        #expect(places == [original])
    }
}

private extension FilePlaceStoreTests {

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

    func makePlace(
        id: UUID = UUID(),
        name: String,
        recognitionRadius: Double = 100
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            id: id,
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: recognitionRadius
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )
    }
}

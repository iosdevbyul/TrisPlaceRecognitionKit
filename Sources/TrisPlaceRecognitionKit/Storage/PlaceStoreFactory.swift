//
//  PlaceStoreFactory.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation

public enum PlaceStoreFactory {

    public static func makeDefaultStore() async throws -> any PlaceStoring {
        let legacyFileURL = try FilePlaceStore.defaultFileURL()

        return try await makeStore(
            legacyFileURL: legacyFileURL
        )
    }
}

extension PlaceStoreFactory {

    static func makeStore(
        legacyFileURL: URL
    ) async throws -> any PlaceStoring {

        if #available(iOS 17.0, *) {
            let swiftDataStore = try SwiftDataPlaceStore()

            return try await makeStore(
                legacyFileURL: legacyFileURL,
                swiftDataStore: swiftDataStore
            )
        }

        return FilePlaceStore(
            fileURL: legacyFileURL
        )
    }

    @available(iOS 17.0, *)
    static func makeStore(
        legacyFileURL: URL,
        swiftDataStore: SwiftDataPlaceStore
    ) async throws -> any PlaceStoring {

        guard FileManager.default.fileExists(
            atPath: legacyFileURL.path
        ) else {
            return swiftDataStore
        }

        let migrator = LegacyPlaceMigrator(
            legacyFileURL: legacyFileURL,
            targetStore: swiftDataStore,
            receiptStore: swiftDataStore
        )

        try await migrator.migrate()

        return swiftDataStore
    }
}

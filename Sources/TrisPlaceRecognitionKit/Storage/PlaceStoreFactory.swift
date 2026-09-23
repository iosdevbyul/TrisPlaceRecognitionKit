//
//  PlaceStoreFactory.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation

enum PlaceStoreBackend: Equatable {
    case file
    case swiftData
}

public enum PlaceStoreFactory {

    public static func makeDefaultStore() throws -> any PlaceStoring {
        let legacyFileURL = try FilePlaceStore.defaultFileURL()

        return try makeStore(
            legacyFileURL: legacyFileURL
        )
    }
}

extension PlaceStoreFactory {

    static func makeStore(
        legacyFileURL: URL
    ) throws -> any PlaceStoring {
        let supportsSwiftData: Bool

        if #available(iOS 17.0, *) {
            supportsSwiftData = true
        } else {
            supportsSwiftData = false
        }

        let legacyFileExists = FileManager.default.fileExists(
            atPath: legacyFileURL.path
        )

        let backend = try selectBackend(
            supportsSwiftData: supportsSwiftData,
            legacyFileExists: legacyFileExists
        )

        if #available(iOS 17.0, *),
           backend == .swiftData {
            return try SwiftDataPlaceStore()
        }

        return FilePlaceStore(
            fileURL: legacyFileURL
        )
    }

    static func selectBackend(
        supportsSwiftData: Bool,
        legacyFileExists: Bool
    ) throws -> PlaceStoreBackend {
        guard supportsSwiftData else {
            return .file
        }

        guard !legacyFileExists else {
            throw PlaceStoreFactoryError.migrationRequired
        }

        return .swiftData
    }
}

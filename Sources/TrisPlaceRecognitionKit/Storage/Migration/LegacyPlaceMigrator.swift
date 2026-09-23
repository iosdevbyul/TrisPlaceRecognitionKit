//
//  LegacyPlaceMigrator.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import CryptoKit

actor LegacyPlaceMigrator {

    private let legacyFileURL: URL
    private let targetStore: any PlaceStoring

    private let markerURL: URL

    init(
        legacyFileURL: URL,
        targetStore: any PlaceStoring
    ) {
        self.legacyFileURL = legacyFileURL
        self.targetStore = targetStore

        self.markerURL = Self.markerURL(
            for: legacyFileURL
        )
    }

    static func markerURL(
        for legacyFileURL: URL
    ) -> URL {
        legacyFileURL
            .deletingPathExtension()
            .appendingPathExtension(
                "migrated.sha256"
            )
    }

    func migrate() async throws {
        guard FileManager.default.fileExists(
            atPath: legacyFileURL.path
        ) else {
            throw PlaceMigrationError.legacyFileMissing
        }

        let originalData = try Data(
            contentsOf: legacyFileURL
        )

        let fingerprint = makeFingerprint(
            for: originalData
        )

        if FileManager.default.fileExists(
            atPath: markerURL.path
        ) {
            let recordedFingerprint = try String(
                contentsOf: markerURL,
                encoding: .utf8
            )

            guard recordedFingerprint == fingerprint else {
                throw PlaceMigrationError.legacyFileChanged
            }

            return
        }

        let legacyPlaces = try JSONDecoder().decode(
            [RegisteredPlace].self,
            from: originalData
        )

        try validateUniqueIDs(
            in: legacyPlaces
        )

        let existingPlaces = try await targetStore.fetchAll()

        // Validate every conflict before writing anything.
        for legacyPlace in legacyPlaces {
            if let existing = existingPlaces.first(
                where: { $0.id == legacyPlace.id }
            ) {
                guard existing == legacyPlace else {
                    throw PlaceMigrationError
                        .conflictingExistingPlace(
                            legacyPlace.id
                        )
                }
            }
        }

        // Previously imported matching places can be skipped.
        for legacyPlace in legacyPlaces {
            let alreadyExists = existingPlaces.contains {
                $0.id == legacyPlace.id
            }

            guard !alreadyExists else {
                continue
            }

            try await targetStore.save(
                legacyPlace
            )
        }

        // Verify every imported place.
        let restoredPlaces = try await targetStore.fetchAll()

        for legacyPlace in legacyPlaces {
            let wasRestored = restoredPlaces.contains {
                $0.id == legacyPlace.id
                    && $0 == legacyPlace
            }

            guard wasRestored else {
                throw PlaceMigrationError.verificationFailed
            }
        }

        // Make sure the source did not change during migration.
        let currentData = try Data(
            contentsOf: legacyFileURL
        )

        guard currentData == originalData else {
            throw PlaceMigrationError.legacyFileChanged
        }

        // Record completion only after all verification succeeds.
        try Data(fingerprint.utf8).write(
            to: markerURL,
            options: .atomic
        )
    }
}

private extension LegacyPlaceMigrator {

    func validateUniqueIDs(
        in places: [RegisteredPlace]
    ) throws {
        var identifiers = Set<UUID>()

        for place in places {
            guard identifiers.insert(place.id).inserted else {
                throw PlaceMigrationError.duplicateLegacyID(
                    place.id
                )
            }
        }
    }

    func makeFingerprint(
        for data: Data
    ) -> String {
        SHA256.hash(
            data: data
        )
        .map {
            String(
                format: "%02x",
                $0
            )
        }
        .joined()
    }
}

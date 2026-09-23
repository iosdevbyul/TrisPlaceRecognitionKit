//
//  PlaceMigrationReceiptStoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

protocol PlaceMigrationReceiptStoring: Sendable {

    func migrationFingerprint(
        for sourcePath: String
    ) async throws -> String?

    func recordMigration(
        for sourcePath: String,
        fingerprint: String
    ) async throws
}

//
//  PlaceStoreFactoryTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceStoreFactoryTests {

    @Test
    func selectsFileStoreForOlderIOS() throws {
        let backend = try PlaceStoreFactory.selectBackend(
            supportsSwiftData: false,
            legacyFileExists: false
        )

        #expect(backend == .file)
    }

    @Test
    func keepsFileStoreForOlderIOSWithExistingData() throws {
        let backend = try PlaceStoreFactory.selectBackend(
            supportsSwiftData: false,
            legacyFileExists: true
        )

        #expect(backend == .file)
    }

    @Test
    func selectsSwiftDataForNewerIOS() throws {
        let backend = try PlaceStoreFactory.selectBackend(
            supportsSwiftData: true,
            legacyFileExists: false
        )

        #expect(backend == .swiftData)
    }

    @Test
    func requiresMigrationWhenLegacyDataExists() {
        do {
            _ = try PlaceStoreFactory.selectBackend(
                supportsSwiftData: true,
                legacyFileExists: true
            )

            Issue.record("Expected migrationRequired")
        } catch let error as PlaceStoreFactoryError {
            #expect(error == .migrationRequired)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func preservesLegacyFileWhenMigrationIsRequired() throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        defer {
            try? FileManager.default.removeItem(
                at: directory
            )
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileURL = directory.appendingPathComponent(
            "registered-places.json"
        )

        let originalData = Data("[]".utf8)

        try originalData.write(
            to: fileURL,
            options: .atomic
        )

        do {
            _ = try PlaceStoreFactory.makeStore(
                legacyFileURL: fileURL
            )

            Issue.record("Expected migrationRequired")
        } catch let error as PlaceStoreFactoryError {
            #expect(error == .migrationRequired)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let currentData = try Data(
            contentsOf: fileURL
        )

        #expect(currentData == originalData)
    }

    @Test
    func createsSwiftDataStoreWhenNoLegacyFileExists() throws {
        guard #available(iOS 17.0, *) else {
            return
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("registered-places.json")

        let store = try PlaceStoreFactory.makeStore(
            legacyFileURL: fileURL
        )

        #expect(store is SwiftDataPlaceStore)
    }
}

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

// Add this file to your current feature branch, not to the legacy worktree.
struct LegacySwiftDataUpgradeTests {

    @Test
    func opensLegacyDatabaseWithoutLosingPlaces() async throws {
        guard #available(iOS 17.0, *) else { return }

        let fixtureDirectory = try #require(
            Bundle.module.resourceURL?.appendingPathComponent(
                "LegacySwiftDataV1", isDirectory: true
            )
        )
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let fixtureFiles = try FileManager.default.contentsOfDirectory(
            at: fixtureDirectory,
            includingPropertiesForKeys: nil
        )
        for file in fixtureFiles where file.lastPathComponent.hasPrefix("places.sqlite") {
            try FileManager.default.copyItem(
                at: file,
                to: temporaryDirectory.appendingPathComponent(file.lastPathComponent)
            )
        }
        let databaseURL = temporaryDirectory.appendingPathComponent("places.sqlite")
        #expect(FileManager.default.fileExists(atPath: databaseURL.path))

        let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let updated: RegisteredPlace

        // First open: use the current schema against an actual V1 database.
        do {
            let store = try makeStore(databaseURL: databaseURL)
            let places = try await store.fetchAll()
            let original = try #require(places.first)

            #expect(places.count == 1)
            #expect(original.id == originalID)
            #expect(original.name.value == "헬스장")
            #expect(original.location.recognitionRadius == 100)
            #expect(original.networkIdentity.ssid == "GYM_MAIN")
            #expect(original.additionalNetworkIdentities.isEmpty)
            #expect(try await store.migrationFingerprint(for: "fixture://legacy-v1")
                == "legacy-v1-fingerprint")

            updated = RegisteredPlace(
                id: original.id,
                name: original.name,
                location: original.location,
                networkIdentity: original.networkIdentity,
                additionalNetworkIdentities: [
                    PlaceNetworkIdentity(
                        ssid: "GYM_SECOND",
                        bssid: "AA:BB:CC:DD:EE:FF"
                    )
                ]
            )
            try await store.save(updated)
        }

        // Second open: added Wi-Fi must be persisted to the upgraded database.
        do {
            let store = try makeStore(databaseURL: databaseURL)
            let restored = try await store.fetchAll()
            #expect(restored == [updated])
            #expect(restored.first?.networkIdentities.count == 2)
        }
    }
}

@available(iOS 17.0, *)
private extension LegacySwiftDataUpgradeTests {
    func makeStore(databaseURL: URL) throws -> SwiftDataPlaceStore {
        let schema = Schema([
            SwiftDataPlaceModel.self,
            SwiftDataPlaceMigrationReceipt.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return SwiftDataPlaceStore(modelContainer: container)
    }
}

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

@available(iOS 17.0, *)
struct PlaceStoreIsolationTests {
    @Test
    func unrelatedDefaultStoreIsNotModifiedOrCopied() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacy = directory.appendingPathComponent("default.store")
        let destination = directory.appendingPathComponent("places.sqlite")
        let schema = Schema([UnrelatedRecord.self])
        let configuration = ModelConfiguration(schema: schema, url: legacy, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(UnrelatedRecord(value: "keep me"))
        try context.save()

        try SwiftDataPlaceStore.preserveLegacyPlacesIfNeeded(
            legacyURL: legacy,
            destinationURL: destination
        )

        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try context.fetch(FetchDescriptor<UnrelatedRecord>()).count == 1)
    }

    @Test
    func legacyPlaceDatabaseIsCopiedAndPreserved() async throws {
        let fixture = try #require(
            Bundle.module.resourceURL?.appendingPathComponent("LegacySwiftDataV1", isDirectory: true)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for file in try FileManager.default.contentsOfDirectory(at: fixture, includingPropertiesForKeys: nil)
        where file.lastPathComponent.hasPrefix("places.sqlite") {
            let suffix = String(file.lastPathComponent.dropFirst("places.sqlite".count))
            try FileManager.default.copyItem(
                at: file,
                to: directory.appendingPathComponent("default.store" + suffix)
            )
        }

        let legacy = directory.appendingPathComponent("default.store")
        let destination = directory.appendingPathComponent("places.sqlite")
        try SwiftDataPlaceStore.preserveLegacyPlacesIfNeeded(
            legacyURL: legacy,
            destinationURL: destination
        )

        #expect(FileManager.default.fileExists(atPath: legacy.path))
        #expect(FileManager.default.fileExists(atPath: destination.path))

        let schema = Schema([
            SwiftDataPlaceModel.self,
            SwiftDataPlaceMigrationReceipt.self
        ])
        let configuration = ModelConfiguration(
            schema: schema, url: destination, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = SwiftDataPlaceStore(modelContainer: container)
        let places = try await store.fetchAll()
        #expect(places.count == 1)
        #expect(places.first?.name.value == "헬스장")
    }
}

@Model
private final class UnrelatedRecord {
    var value: String
    init(value: String) { self.value = value }
}

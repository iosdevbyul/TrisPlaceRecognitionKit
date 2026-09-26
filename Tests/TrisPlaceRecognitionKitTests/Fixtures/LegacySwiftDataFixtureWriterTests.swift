import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

// Add this file ONLY to the temporary worktree at commit eb6bd97.
struct LegacySwiftDataFixtureWriterTests {

    @Test
    func writesLegacySwiftDataFixture() throws {
        guard #available(iOS 17.0, *) else { return }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrisPlaceRecognitionLegacyV1", isDirectory: true)
        let databaseURL = directoryURL.appendingPathComponent("places.sqlite")

        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        // Compiled against the actual old @Model without additionalNetworksData.
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
        let context = ModelContext(container)

        context.insert(
            SwiftDataPlaceModel(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "헬스장",
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100,
                ssid: "GYM_MAIN",
                bssid: "11:22:33:44:55:66"
            )
        )
        context.insert(
            SwiftDataPlaceMigrationReceipt(
                sourcePath: "fixture://legacy-v1",
                fingerprint: "legacy-v1-fingerprint"
            )
        )
        try context.save()
        let saved = try context.fetch(FetchDescriptor<SwiftDataPlaceModel>())
        #expect(saved.count == 1)
        print("LEGACY_FIXTURE_DIRECTORY=\(directoryURL.path)")
    }
}

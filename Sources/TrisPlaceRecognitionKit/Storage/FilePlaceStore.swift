//
//  FilePlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation

public actor FilePlaceStore: PlaceStoring {

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        return applicationSupportURL
            .appendingPathComponent(
                "TrisPlaceRecognitionKit",
                isDirectory: true
            )
            .appendingPathComponent(
                "registered-places.json",
                isDirectory: false
            )
    }

    public func save(
        _ place: RegisteredPlace
    ) async throws {
        var places = try loadPlaces()

        if let index = places.firstIndex(
            where: { $0.id == place.id }
        ) {
            places[index] = place
        } else {
            places.append(place)
        }

        try persist(places)
    }

    public func fetchAll() async throws -> [RegisteredPlace] {
        try loadPlaces()
    }

    public func delete(
        id: UUID
    ) async throws {
        var places = try loadPlaces()

        guard let index = places.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        places.remove(at: index)

        try persist(places)
    }
}

private extension FilePlaceStore {

    func loadPlaces() throws -> [RegisteredPlace] {
        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)

        return try JSONDecoder().decode(
            [RegisteredPlace].self,
            from: data
        )
    }

    func persist(
        _ places: [RegisteredPlace]
    ) throws {
        let data = try JSONEncoder().encode(places)

        let directoryURL = fileURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        try data.write(
            to: fileURL,
            options: .atomic
        )
    }
}

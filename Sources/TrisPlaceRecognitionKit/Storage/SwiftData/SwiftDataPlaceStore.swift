//
//  SwiftDataPlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
public actor SwiftDataPlaceStore: PlaceStoring {

    private let modelContainer: ModelContainer

    public init(
        modelContainer: ModelContainer
    ) {
        self.modelContainer = modelContainer
    }

    public init() throws {
        let schema = Schema([
            SwiftDataPlaceModel.self
        ])

        let configuration = ModelConfiguration(
            schema: schema
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    public func save(
        _ place: RegisteredPlace
    ) async throws {
        let context = ModelContext(
            modelContainer
        )

        let placeID = place.id

        let descriptor = FetchDescriptor<SwiftDataPlaceModel>(
            predicate: #Predicate {
                $0.id == placeID
            }
        )

        if let existing = try context.fetch(
            descriptor
        ).first {
            existing.name = place.name.value
            existing.latitude = place.location.latitude
            existing.longitude = place.location.longitude
            existing.recognitionRadius =
                place.location.recognitionRadius
            existing.ssid =
                place.networkIdentity.ssid
            existing.bssid =
                place.networkIdentity.bssid
        } else {
            let model = SwiftDataPlaceModel(
                id: place.id,
                name: place.name.value,
                latitude: place.location.latitude,
                longitude: place.location.longitude,
                recognitionRadius:
                    place.location.recognitionRadius,
                ssid: place.networkIdentity.ssid,
                bssid: place.networkIdentity.bssid
            )

            context.insert(model)
        }

        try context.save()
    }

    public func fetchAll() async throws -> [RegisteredPlace] {
        let context = ModelContext(
            modelContainer
        )

        let descriptor = FetchDescriptor<SwiftDataPlaceModel>()

        let models = try context.fetch(
            descriptor
        )

        return try models.map {
            try makeRegisteredPlace(
                from: $0
            )
        }
    }

    public func delete(
        id: UUID
    ) async throws {
        let context = ModelContext(
            modelContainer
        )

        let placeID = id

        let descriptor = FetchDescriptor<SwiftDataPlaceModel>(
            predicate: #Predicate {
                $0.id == placeID
            }
        )

        guard let model = try context.fetch(
            descriptor
        ).first else {
            return
        }

        context.delete(model)

        try context.save()
    }
}

@available(iOS 17.0, *)
private extension SwiftDataPlaceStore {

    func makeRegisteredPlace(
        from model: SwiftDataPlaceModel
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            id: model.id,
            name: try PlaceName(
                model.name
            ),
            location: PlaceLocation(
                latitude: model.latitude,
                longitude: model.longitude,
                recognitionRadius:
                    model.recognitionRadius
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: model.ssid,
                bssid: model.bssid
            )
        )
    }
}

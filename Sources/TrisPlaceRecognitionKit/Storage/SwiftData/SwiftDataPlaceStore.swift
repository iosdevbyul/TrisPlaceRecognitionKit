//
//  SwiftDataPlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@ModelActor
public actor SwiftDataPlaceStore:
    PlaceStoring,
    PlaceMigrationReceiptStoring {

    public init() throws {

        let schema =
            Schema([
                SwiftDataPlaceModel.self,
                SwiftDataPlaceMigrationReceipt.self
            ])

        let configuration =
            ModelConfiguration(
                schema:
                    schema
            )

        let container =
            try ModelContainer(
                for:
                    schema,
                configurations: [
                    configuration
                ]
            )

        self.init(
            modelContainer:
                container
        )
    }

    public func save(
        _ place:
            RegisteredPlace
    ) async throws {

        let additionalNetworksData =
            place
                .additionalNetworkIdentities
                .isEmpty
            ? nil
            : try JSONEncoder()
                .encode(
                    place
                        .additionalNetworkIdentities
                )

        let placeID =
            place.id

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceModel
            >(
                predicate:
                    #Predicate {
                        $0.id
                            == placeID
                    }
            )

        if let existing =
            try modelContext
                .fetch(
                    descriptor
                )
                .first {

            existing.name =
                place.name.value

            existing.latitude =
                place.location?.latitude

            existing.longitude =
                place.location?.longitude

            existing.recognitionRadius =
                place.location?.recognitionRadius

            existing.ssid =
                place.networkIdentity
                    .ssid

            existing.bssid =
                place.networkIdentity
                    .bssid

            existing.additionalNetworksData =
                additionalNetworksData

        } else {

            let model =
                SwiftDataPlaceModel(
                    id:
                        place.id,
                    name:
                        place.name.value,
                    latitude:
                        place.location?.latitude,
                    longitude:
                        place.location?.longitude,
                    recognitionRadius:
                        place.location?.recognitionRadius,
                    ssid:
                        place.networkIdentity
                            .ssid,
                    bssid:
                        place.networkIdentity
                            .bssid,
                    additionalNetworksData:
                        additionalNetworksData
                )

            modelContext
                .insert(
                    model
                )
        }

        do {

            try modelContext
                .save()

        } catch {

            modelContext
                .rollback()

            throw error
        }
    }

    public func fetchAll()
        async throws
        -> [RegisteredPlace] {

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceModel
            >()

        let models =
            try modelContext
                .fetch(
                    descriptor
                )

        return try models.map {

            try makeRegisteredPlace(
                from:
                    $0
            )
        }
    }

    public func delete(
        id:
            UUID
    ) async throws {

        let placeID =
            id

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceModel
            >(
                predicate:
                    #Predicate {
                        $0.id
                            == placeID
                    }
            )

        guard
            let model =
                try modelContext
                    .fetch(
                        descriptor
                    )
                    .first
        else {

            return
        }

        modelContext
            .delete(
                model
            )

        do {

            try modelContext
                .save()

        } catch {

            modelContext
                .rollback()

            throw error
        }
    }

    public func update(
        id:
            UUID,
        _ transform:
            @Sendable (
                RegisteredPlace
            ) throws
                -> RegisteredPlace
    ) async throws
        -> RegisteredPlace? {

        let placeID =
            id

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceModel
            >(
                predicate:
                    #Predicate {
                        $0.id
                            == placeID
                    }
            )

        guard
            let model =
                try modelContext
                    .fetch(
                        descriptor
                    )
                    .first
        else {

            return nil
        }

        let original =
            try makeRegisteredPlace(
                from:
                    model
            )

        let updated =
            try transform(
                original
            )

        guard
            updated.id
                == id
        else {

            throw PlaceMutationError
                .identifierChanged
        }

        let additionalNetworksData =
            updated
                .additionalNetworkIdentities
                .isEmpty
            ? nil
            : try JSONEncoder()
                .encode(
                    updated
                        .additionalNetworkIdentities
                )

        model.name =
            updated.name.value

        model.latitude =
            updated.location?.latitude

        model.longitude =
            updated.location?.longitude

        model.recognitionRadius =
            updated.location?.recognitionRadius

        model.ssid =
            updated.networkIdentity
                .ssid

        model.bssid =
            updated.networkIdentity
                .bssid

        model.additionalNetworksData =
            additionalNetworksData

        do {

            try modelContext
                .save()

        } catch {

            modelContext
                .rollback()

            throw error
        }

        return updated
    }
}

// MARK: - Mapping

@available(iOS 17.0, *)
private extension
    SwiftDataPlaceStore {

    func makeRegisteredPlace(
        from model:
            SwiftDataPlaceModel
    ) throws
        -> RegisteredPlace {

        let additionalNetworks:
            [PlaceNetworkIdentity]

        if let data =
            model.additionalNetworksData {

            additionalNetworks =
                try JSONDecoder()
                    .decode(
                        [
                            PlaceNetworkIdentity
                        ].self,
                        from:
                            data
                    )

        } else {

            additionalNetworks =
                []
        }

        return RegisteredPlace(
            id:
                model.id,
            name:
                try PlaceName(
                    model.name
                ),
            location:
                makeLocation(
                    from:
                        model
                ),
            networkIdentity:
                PlaceNetworkIdentity(
                    ssid:
                        model.ssid,
                    bssid:
                        model.bssid
                ),
            additionalNetworkIdentities:
                additionalNetworks
        )
    }

    func makeLocation(
        from model: SwiftDataPlaceModel
    ) -> PlaceLocation? {
        guard
            let latitude = model.latitude,
            let longitude = model.longitude,
            let recognitionRadius = model.recognitionRadius
        else {
            return nil
        }

        return PlaceLocation(
            latitude: latitude,
            longitude: longitude,
            recognitionRadius: recognitionRadius
        )
    }
}

// MARK: - Migration Receipt

@available(iOS 17.0, *)
extension SwiftDataPlaceStore {

    func migrationFingerprint(
        for sourcePath:
            String
    ) async throws
        -> String? {

        let path =
            sourcePath

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceMigrationReceipt
            >(
                predicate:
                    #Predicate {
                        $0.sourcePath
                            == path
                    }
            )

        return try modelContext
            .fetch(
                descriptor
            )
            .first?
            .fingerprint
    }

    func recordMigration(
        for sourcePath:
            String,
        fingerprint:
            String
    ) async throws {

        let path =
            sourcePath

        let descriptor =
            FetchDescriptor<
                SwiftDataPlaceMigrationReceipt
            >(
                predicate:
                    #Predicate {
                        $0.sourcePath
                            == path
                    }
            )

        if let existing =
            try modelContext
                .fetch(
                    descriptor
                )
                .first {

            existing.fingerprint =
                fingerprint

        } else {

            modelContext
                .insert(
                    SwiftDataPlaceMigrationReceipt(
                        sourcePath:
                            sourcePath,
                        fingerprint:
                            fingerprint
                    )
                )
        }

        do {

            try modelContext
                .save()

        } catch {

            modelContext
                .rollback()

            throw error
        }
    }
}

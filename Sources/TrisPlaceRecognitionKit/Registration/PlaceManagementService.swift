//
//  PlaceManagementService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//

import Foundation
import TrisLocationKit

@MainActor
public final class PlaceManagementService {

    private let placeStore: any PlaceStoring
    private let locationProvider: any LocationProviding
    private let locationQualityPolicy: PlaceLocationQualityPolicy

    public init(
        placeStore: any PlaceStoring,
        locationProvider: any LocationProviding,
        locationQualityPolicy: PlaceLocationQualityPolicy = .init()
    ) {
        self.placeStore = placeStore
        self.locationProvider = locationProvider
        self.locationQualityPolicy = locationQualityPolicy
    }

    public func fetchPlaces() async throws -> [RegisteredPlace] {
        try await placeStore.fetchAll()
    }

    public func renamePlace(
        id: UUID,
        to name: String
    ) async throws -> RegisteredPlace {
        let validatedName = try PlaceName(name)

        return try await updateExisting(id: id) { place in
            var updated = place
            updated.name = validatedName
            return updated
        }
    }

    public func updateRecognitionRadius(
        for id: UUID,
        to radius: Double
    ) async throws -> RegisteredPlace {
        guard radius.isFinite, radius > 0 else {
            throw PlaceManagementError.invalidRecognitionRadius
        }

        return try await updateExisting(id: id) { place in
            let location = PlaceLocation(
                latitude: place.location.latitude,
                longitude: place.location.longitude,
                recognitionRadius: radius
            )

            return RegisteredPlace(
                id: place.id,
                name: place.name,
                location: location,
                networkIdentity: place.networkIdentity,
                additionalNetworkIdentities:
                    place.additionalNetworkIdentities
            )
        }
    }

    public func updateCurrentLocation(
        for id: UUID
    ) async throws -> RegisteredPlace {
        let current = try await locationProvider
            .requestCurrentLocation()

        guard PlaceLocationQualityValidator.isAcceptable(
            current,
            policy: locationQualityPolicy
        ),
        current.latitude.isFinite,
        current.longitude.isFinite,
        (-90...90).contains(current.latitude),
        (-180...180).contains(current.longitude) else {
            throw PlaceManagementError.invalidCurrentLocation
        }

        let latitude = current.latitude
        let longitude = current.longitude
        let accuracy = current.horizontalAccuracy

        return try await updateExisting(id: id) { place in
            guard accuracy <= place.location.recognitionRadius else {
                throw PlaceManagementError.invalidCurrentLocation
            }

            let location = PlaceLocation(
                latitude: latitude,
                longitude: longitude,
                recognitionRadius: place.location.recognitionRadius
            )

            return RegisteredPlace(
                id: place.id,
                name: place.name,
                location: location,
                networkIdentity: place.networkIdentity,
                additionalNetworkIdentities:
                    place.additionalNetworkIdentities
            )
        }
    }

    public func deletePlace(
        id: UUID
    ) async throws {
        _ = try await findPlace(id: id)

        try await placeStore.delete(id: id)
    }
}

private extension PlaceManagementService {

    func findPlace(
        id: UUID
    ) async throws -> RegisteredPlace {
        let places = try await placeStore.fetchAll()

        guard let place = places.first(where: {
            $0.id == id
        }) else {
            throw PlaceManagementError.placeNotFound(id)
        }

        return place
    }

    func save(
        place: RegisteredPlace,
        name: PlaceName,
        location: PlaceLocation
    ) async throws -> RegisteredPlace {
        let updated = RegisteredPlace(
            id: place.id,
            name: name,
            location: location,
            networkIdentity: place.networkIdentity,
            additionalNetworkIdentities:
                place.additionalNetworkIdentities
        )

        try await placeStore.save(updated)

        return updated
    }
    
    func updateExisting(
        id: UUID,
        _ transform: @Sendable (RegisteredPlace) throws -> RegisteredPlace
    ) async throws -> RegisteredPlace {
        guard let updated = try await placeStore.update(
            id: id,
            transform
        ) else {
            throw PlaceManagementError.placeNotFound(id)
        }

        return updated
    }
}

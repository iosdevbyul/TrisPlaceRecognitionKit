//
//  InMemoryPlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-23.
//

import Foundation

public actor InMemoryPlaceStore: PlaceStoring {

    private var storedPlaces: [RegisteredPlace] = []

    public init() {}

    public func save(
        _ place: RegisteredPlace
    ) async throws {
        if let index = storedPlaces.firstIndex(
            where: { $0.id == place.id }
        ) {
            storedPlaces[index] = place
        } else {
            storedPlaces.append(place)
        }
    }

    public func fetchAll() async throws -> [RegisteredPlace] {
        storedPlaces
    }

    public func delete(
        id: UUID
    ) async throws {
        storedPlaces.removeAll {
            $0.id == id
        }
    }
    
    public func update(
        id: UUID,
        _ transform: @Sendable (RegisteredPlace) throws -> RegisteredPlace
    ) async throws -> RegisteredPlace? {
        guard let index = storedPlaces.firstIndex(where: {
            $0.id == id
        }) else {
            return nil
        }

        let updated = try transform(storedPlaces[index])

        guard updated.id == id else {
            throw PlaceMutationError.identifierChanged
        }

        storedPlaces[index] = updated

        return updated
    }
}

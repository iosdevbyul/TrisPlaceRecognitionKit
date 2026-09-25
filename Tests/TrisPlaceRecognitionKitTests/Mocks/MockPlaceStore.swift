//
//  MockPlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation

@testable import TrisPlaceRecognitionKit

actor MockPlaceStore: PlaceStoring {

    private(set) var savedPlaces: [RegisteredPlace] = []

    var saveError: Error?
    var fetchError: Error?
    var deleteError: Error?

    func save(
        _ place: RegisteredPlace
    ) async throws {
        if let saveError {
            throw saveError
        }

        if let index = savedPlaces.firstIndex(
            where: { $0.id == place.id }
        ) {
            savedPlaces[index] = place
        } else {
            savedPlaces.append(place)
        }
    }

    func fetchAll() async throws -> [RegisteredPlace] {
        if let fetchError {
            throw fetchError
        }

        return savedPlaces
    }

    func delete(
        id: UUID
    ) async throws {
        if let deleteError {
            throw deleteError
        }

        savedPlaces.removeAll {
            $0.id == id
        }
    }

    func savedPlaceCount() -> Int {
        savedPlaces.count
    }

    func lastSavedPlace() -> RegisteredPlace? {
        savedPlaces.last
    }
    
    func update(
        id: UUID,
        _ transform: @Sendable (RegisteredPlace) throws -> RegisteredPlace
    ) async throws -> RegisteredPlace? {
        if let fetchError {
            throw fetchError
        }

        guard let index = savedPlaces.firstIndex(where: {
            $0.id == id
        }) else {
            return nil
        }

        let updated = try transform(savedPlaces[index])

        guard updated.id == id else {
            throw PlaceMutationError.identifierChanged
        }

        if let saveError {
            throw saveError
        }

        savedPlaces[index] = updated

        return updated
    }
}

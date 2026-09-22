//
//  MockPlaceStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

@testable import TrisPlaceRecognitionKit

actor MockPlaceStore: PlaceStoring {

    private(set) var savedPlaces: [RegisteredPlace] = []

    var saveError: Error?

    func save(
        _ place: RegisteredPlace
    ) async throws {
        if let saveError {
            throw saveError
        }

        savedPlaces.append(place)
    }

    func savedPlaceCount() -> Int {
        savedPlaces.count
    }

    func lastSavedPlace() -> RegisteredPlace? {
        savedPlaces.last
    }
}

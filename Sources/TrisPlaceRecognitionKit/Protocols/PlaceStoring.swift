//
//  PlaceStoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation

public enum PlaceMutationError: Error, Sendable, Equatable {
    case identifierChanged
}

public protocol PlaceStoring: Sendable {

    func save(
        _ place: RegisteredPlace
    ) async throws

    func fetchAll() async throws -> [RegisteredPlace]

    func delete(
        id: UUID
    ) async throws

    func update(
        id: UUID,
        _ transform: @Sendable (RegisteredPlace) throws -> RegisteredPlace
    ) async throws -> RegisteredPlace?
}

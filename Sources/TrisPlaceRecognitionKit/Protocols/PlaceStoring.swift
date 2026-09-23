//
//  PlaceStoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation

public protocol PlaceStoring: Sendable {

    func save(
        _ place: RegisteredPlace
    ) async throws

    func fetchAll() async throws -> [RegisteredPlace]

    func delete(
        id: UUID
    ) async throws
}

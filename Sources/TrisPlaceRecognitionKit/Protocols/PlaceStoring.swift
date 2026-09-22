//
//  PlaceStoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

public protocol PlaceStoring: Sendable {

    func save(
        _ place: RegisteredPlace
    ) async throws
}

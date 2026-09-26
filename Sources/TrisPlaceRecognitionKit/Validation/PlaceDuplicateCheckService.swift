//
//  PlaceDuplicateCheckService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//

@MainActor
public final class PlaceDuplicateCheckService {

    private let placeStore: any PlaceStoring

    public init(placeStore: any PlaceStoring) {
        self.placeStore = placeStore
    }

    public func check(
        candidate: RegisteredPlace
    ) async throws -> [PlaceDuplicateWarning] {
        let existingPlaces = try await placeStore.fetchAll()

        return PlaceDuplicateDetector.warnings(
            for: candidate,
            among: existingPlaces
        )
    }
}

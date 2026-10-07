//
//  PlaceRecognitionCardCountModel.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-07.
//

import Combine
import Foundation

/// Loads the total number of saved places, independently of which
/// place is currently recognized by the location monitor.
@MainActor
final class PlaceRecognitionCardCountModel: ObservableObject {
    @Published
    private(set) var count: Int?

    private var loadRevision: UInt64 = 0

    func reload(placeStore: (any PlaceStoring)?) async {
        loadRevision &+= 1
        let revision = loadRevision

        guard let placeStore else {
            count = nil
            return
        }

        do {
            let places = try await placeStore.fetchAll()

            guard revision == loadRevision else {
                return
            }

            count = places.count
        } catch {
            guard revision == loadRevision else {
                return
            }

            // Never report 0 when loading actually failed.
            count = nil
        }
    }
}

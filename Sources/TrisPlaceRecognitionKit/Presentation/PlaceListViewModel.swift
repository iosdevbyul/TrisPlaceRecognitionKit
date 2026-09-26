//
//  PlaceListViewModel.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Combine
import Foundation

@MainActor
public final class PlaceListViewModel: ObservableObject {

    @Published
    public private(set) var places: [RegisteredPlace] = []

    @Published
    public private(set) var isLoading = false

    @Published
    public private(set) var errorMessage: String?

    private let placeStore: any PlaceStoring
    private var loadRevision: UInt64 = 0

    public init(placeStore: any PlaceStoring) {
        self.placeStore = placeStore
    }

    public func load() async {
        loadRevision &+= 1
        let revision = loadRevision

        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await placeStore.fetchAll()

            guard revision == loadRevision else {
                return
            }

            places = fetched.sorted { lhs, rhs in
                if lhs.name.value != rhs.name.value {
                    return lhs.name.value < rhs.name.value
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }

            isLoading = false
        } catch {
            guard revision == loadRevision else {
                return
            }

            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

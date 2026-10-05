//
//  MockPlaceVisitNotifier.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-05.
//

import Foundation

@testable import TrisPlaceRecognitionKit

actor MockPlaceVisitNotifier:
    PlaceVisitNotifying {

    private(set)
    var arrivalPlaceNames:
        [String] = []

    private(set)
    var departurePlaceNames:
        [String] = []

    var error:
        Error?

    func notifyArrival(
        placeName: String
    ) async throws {

        if let error {
            throw error
        }

        arrivalPlaceNames.append(
            placeName
        )
    }

    func notifyDeparture(
        placeName: String
    ) async throws {

        if let error {
            throw error
        }

        departurePlaceNames.append(
            placeName
        )
    }
}

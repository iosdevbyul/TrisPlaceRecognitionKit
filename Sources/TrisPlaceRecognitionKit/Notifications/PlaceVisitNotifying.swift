//
//  PlaceVisitNotifying.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-05.
//

import Foundation

protocol PlaceVisitNotifying: Sendable {

    func notifyArrival(
        placeName: String
    ) async throws

    func notifyDeparture(
        placeName: String
    ) async throws
}

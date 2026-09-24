//
//  PlaceDuplicateWarning.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//

import Foundation

public enum PlaceDuplicateReason: Sendable, Equatable {
    case sameBSSID
    case sameSSID
    case overlappingGPS(distanceMeters: Double)
}

public struct PlaceDuplicateWarning: Sendable, Equatable {

    public let existingPlace: RegisteredPlace
    public let reasons: [PlaceDuplicateReason]

    public init(
        existingPlace: RegisteredPlace,
        reasons: [PlaceDuplicateReason]
    ) {
        self.existingPlace = existingPlace
        self.reasons = reasons
    }
}

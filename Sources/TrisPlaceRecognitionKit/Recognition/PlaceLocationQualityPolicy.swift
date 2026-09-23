//
//  PlaceLocationQualityPolicy.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation

public struct PlaceLocationQualityPolicy: Sendable, Equatable {

    public let maximumHorizontalAccuracy: Double
    public let maximumAge: TimeInterval
    public let futureTolerance: TimeInterval

    public init(
        maximumHorizontalAccuracy: Double = 100,
        maximumAge: TimeInterval = 30,
        futureTolerance: TimeInterval = 5
    ) {
        self.maximumHorizontalAccuracy = maximumHorizontalAccuracy
        self.maximumAge = maximumAge
        self.futureTolerance = futureTolerance
    }
}

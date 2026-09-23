//
//  PlaceLocation.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

public struct PlaceLocation: Sendable,
                             Equatable,
                             Hashable,
                             Codable {

    public let latitude: Double
    public let longitude: Double
    public let recognitionRadius: Double

    public init(
        latitude: Double,
        longitude: Double,
        recognitionRadius: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.recognitionRadius = recognitionRadius
    }
}

//
//  RecognizedPlace.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

public enum PlaceRecognitionEvidence: Sendable, Equatable {
    case bssid
    case ssid
    case gpsOnlyWiFiUnavailable
    case gpsOnlyNoWiFiConfigured
}

public struct RecognizedPlace: Sendable, Equatable {

    public let place: RegisteredPlace
    public let distanceMeters: Double?
    public let evidence: PlaceRecognitionEvidence

    public init(
        place: RegisteredPlace,
        distanceMeters: Double?,
        evidence: PlaceRecognitionEvidence
    ) {
        self.place = place
        self.distanceMeters = distanceMeters
        self.evidence = evidence
    }
}

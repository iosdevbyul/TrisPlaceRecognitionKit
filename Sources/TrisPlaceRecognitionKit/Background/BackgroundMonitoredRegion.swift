//
//  BackgroundMonitoredRegion.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

struct BackgroundMonitoredRegion:
    Identifiable,
    Sendable,
    Equatable {

    let placeID: UUID

    let latitude: Double
    let longitude: Double
    let radius: Double

    var id: UUID {
        placeID
    }

    init(
        candidate: BackgroundMonitoringCandidate
    ) {
        placeID = candidate.place.id

        latitude =
            candidate.place.location.latitude

        longitude =
            candidate.place.location.longitude

        radius =
            candidate.place.location.recognitionRadius
    }
}

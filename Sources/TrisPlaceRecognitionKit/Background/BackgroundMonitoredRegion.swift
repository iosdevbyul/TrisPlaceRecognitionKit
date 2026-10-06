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

    init?(
        candidate: BackgroundMonitoringCandidate
    ) {
        guard let location = candidate.place.location else {
            return nil
        }

        placeID = candidate.place.id
        latitude = location.latitude
        longitude = location.longitude
        radius = location.recognitionRadius
    }
}

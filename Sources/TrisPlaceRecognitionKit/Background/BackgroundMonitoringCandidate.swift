//
//  BackgroundMonitoringCandidate.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

struct BackgroundMonitoringCandidate:
    Identifiable,
    Sendable,
    Equatable {

    let place: RegisteredPlace

    let distanceMeters: Double

    var id: UUID {
        place.id
    }
}

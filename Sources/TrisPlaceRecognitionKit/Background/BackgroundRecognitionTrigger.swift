//
//  BackgroundRecognitionTrigger.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

enum BackgroundRecognitionTrigger:
    Sendable,
    Equatable {

    case monitoredRegionEntered(
        placeID: UUID
    )

    case monitoredRegionExited(
        placeID: UUID
    )

    case significantLocationChange
}

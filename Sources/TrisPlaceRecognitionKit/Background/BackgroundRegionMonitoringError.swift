//
//  BackgroundRegionMonitoringError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

enum BackgroundRegionMonitoringError:
    Error,
    Sendable,
    Equatable {

    case monitoringUnavailable

    case candidateRefreshMonitoringUnavailable

    case invalidCoordinate(
        placeID: UUID
    )

    case invalidRadius(
        placeID: UUID
    )

    case radiusExceedsMaximum(
        placeID: UUID,
        maximum: Double
    )

    case insufficientSystemCapacity(
        requested: Int,
        available: Int
    )

    case systemMonitoringFailed(
        placeID: UUID?
    )
}

//
//  PlaceManagementError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//

import Foundation

public enum PlaceManagementError: Error,
                                  Sendable,
                                  Equatable {
    case placeNotFound(UUID)
    case invalidRecognitionRadius
    case invalidCurrentLocation
}

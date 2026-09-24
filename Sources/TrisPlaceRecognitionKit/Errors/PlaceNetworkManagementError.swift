//
//  PlaceNetworkManagementError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//

import Foundation

public enum PlaceNetworkManagementError: Error,
                                         Sendable,
                                         Equatable {
    case placeNotFound(UUID)
    case currentWiFiUnavailable
    case networkNotRegistered
}

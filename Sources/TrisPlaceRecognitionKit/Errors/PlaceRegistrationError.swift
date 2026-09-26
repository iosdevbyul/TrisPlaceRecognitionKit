//
//  PlaceRegistrationError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

public enum PlaceRegistrationError: Error,
                                    Sendable,
                                    Equatable {
    case emptyName
    case nameTooLong
    case currentWiFiUnavailable
}

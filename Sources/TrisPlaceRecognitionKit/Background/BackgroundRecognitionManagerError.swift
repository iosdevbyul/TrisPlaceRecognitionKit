//
//  BackgroundRecognitionManagerError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

public enum BackgroundRecognitionManagerError:
    Error,
    Sendable,
    Equatable {

    case alwaysAuthorizationRequired

    case authorizationDenied

    case authorizationRestricted

    case authorizationUnknown

    case unacceptableLocationSnapshot
}

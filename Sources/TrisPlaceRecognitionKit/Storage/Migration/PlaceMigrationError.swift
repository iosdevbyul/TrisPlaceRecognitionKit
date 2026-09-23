//
//  PlaceMigrationError.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation

public enum PlaceMigrationError: Error,
                                 Sendable,
                                 Equatable {

    case duplicateLegacyID(UUID)
    case conflictingExistingPlace(UUID)
    case verificationFailed
    case legacyFileChanged
    case legacyFileMissing
}

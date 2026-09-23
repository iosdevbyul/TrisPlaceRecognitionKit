//
//  SwiftDataPlaceMigrationReceipt.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class SwiftDataPlaceMigrationReceipt {

    @Attribute(.unique)
    var sourcePath: String

    var fingerprint: String

    init(
        sourcePath: String,
        fingerprint: String
    ) {
        self.sourcePath = sourcePath
        self.fingerprint = fingerprint
    }
}

//
//  StoredPlaceVisit.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class StoredPlaceVisit {

    @Attribute(.unique)
    var id: UUID

    var placeID: UUID
    var startedAt: Date
    var endedAt: Date?

    var arrivalEvidenceRawValue: String

    init(
        id: UUID,
        placeID: UUID,
        startedAt: Date,
        endedAt: Date?,
        arrivalEvidenceRawValue: String
    ) {
        self.id = id
        self.placeID = placeID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.arrivalEvidenceRawValue = arrivalEvidenceRawValue
    }
}

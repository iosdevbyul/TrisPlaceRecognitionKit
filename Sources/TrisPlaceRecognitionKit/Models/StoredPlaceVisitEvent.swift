//
//  StoredPlaceVisitEvent.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
@Model
final class StoredPlaceVisitEvent {

    @Attribute(.unique)
    var id: UUID

    var visitID: UUID
    var placeID: UUID

    var kindRawValue: String
    var occurredAt: Date

    init(
        id: UUID,
        visitID: UUID,
        placeID: UUID,
        kindRawValue: String,
        occurredAt: Date
    ) {
        self.id = id
        self.visitID = visitID
        self.placeID = placeID
        self.kindRawValue = kindRawValue
        self.occurredAt = occurredAt
    }
}

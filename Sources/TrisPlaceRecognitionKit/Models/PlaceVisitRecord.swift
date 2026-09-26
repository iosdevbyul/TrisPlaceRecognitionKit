//
//  PlaceVisitRecord.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//


import Foundation

public struct PlaceVisitRecord: Identifiable,
                                Sendable,
                                Equatable {

    public let id: UUID
    public let placeID: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let arrivalEvidence: PlaceRecognitionEvidence

    public var isActive: Bool {
        endedAt == nil
    }

    public var duration: TimeInterval? {
        guard let endedAt else {
            return nil
        }

        return endedAt.timeIntervalSince(startedAt)
    }

    public init(
        id: UUID = UUID(),
        placeID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        arrivalEvidence: PlaceRecognitionEvidence
    ) {
        self.id = id
        self.placeID = placeID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.arrivalEvidence = arrivalEvidence
    }

    public func ending(at date: Date) -> PlaceVisitRecord {
        PlaceVisitRecord(
            id: id,
            placeID: placeID,
            startedAt: startedAt,
            endedAt: max(date, startedAt),
            arrivalEvidence: arrivalEvidence
        )
    }
}

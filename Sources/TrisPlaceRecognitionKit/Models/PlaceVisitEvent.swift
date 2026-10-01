//
//  PlaceVisitEvent.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//


import Foundation

public struct PlaceVisitEvent: Sendable, Equatable {

    public enum Kind: String, Sendable, Equatable {
        case arrived
        case departed
    }

    public let id: UUID
    public let visitID: UUID
    public let placeID: UUID
    public let kind: Kind
    public let occurredAt: Date

    public init(
        id: UUID = UUID(),
        visitID: UUID,
        placeID: UUID,
        kind: Kind,
        occurredAt: Date
    ) {
        self.id = id
        self.visitID = visitID
        self.placeID = placeID
        self.kind = kind
        self.occurredAt = occurredAt
    }
}

// A single successful recognition update can produce
// multiple events when multiple places are monitored.
public struct PlaceVisitUpdate: Sendable, Equatable {

    public let events: [PlaceVisitEvent]
    public let startedVisits: [PlaceVisitRecord]
    public let endedVisits: [PlaceVisitRecord]

    public init(
        events: [PlaceVisitEvent] = [],
        startedVisits: [PlaceVisitRecord] = [],
        endedVisits: [PlaceVisitRecord] = []
    ) {
        self.events = events
        self.startedVisits = startedVisits
        self.endedVisits = endedVisits
    }
}

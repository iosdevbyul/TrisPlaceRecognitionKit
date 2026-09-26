//
//  PlaceVisitStoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation

public enum PlaceVisitStorageError: Error, Sendable, Equatable {
    case duplicateVisit
    case activeVisitAlreadyExists
    case visitNotFound
    case visitAlreadyEnded
    case invalidVisitRecord
    case invalidVisitEvent
    case duplicateEvent
}

public protocol PlaceVisitStoring: Sendable {

    // Atomically persist visit records and their events.
    func apply(
        _ update: PlaceVisitUpdate
    ) async throws

    // Return all visits, including active visits.
    func fetchAll() async throws -> [PlaceVisitRecord]

    // Return visits that have not ended.
    func fetchActiveVisits() async throws -> [PlaceVisitRecord]

    // Return events in chronological order.
    func fetchEvents() async throws -> [PlaceVisitEvent]
}

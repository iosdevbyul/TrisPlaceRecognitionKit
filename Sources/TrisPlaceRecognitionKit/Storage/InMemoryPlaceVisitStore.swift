//
//  InMemoryPlaceVisitStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation

public actor InMemoryPlaceVisitStore: PlaceVisitStoring {

    private var visits: [UUID: PlaceVisitRecord] = [:]
    private var events: [UUID: PlaceVisitEvent] = [:]

    public init() {}

    public func apply(
        _ update: PlaceVisitUpdate
    ) async throws {

        // Validate all changes before modifying stored data.
        var nextVisits = visits
        var nextEvents = events

        var expectedEvents: [VisitEventKey: Date] = [:]

        // MARK: - Start Visits

        for record in update.startedVisits {

            guard record.endedAt == nil,
                  record.startedAt.timeIntervalSince1970.isFinite else {
                throw PlaceVisitStorageError.invalidVisitRecord
            }

            guard nextVisits[record.id] == nil else {
                throw PlaceVisitStorageError.duplicateVisit
            }

            let hasActiveVisit = nextVisits.values.contains {
                $0.placeID == record.placeID && $0.isActive
            }

            guard !hasActiveVisit else {
                throw PlaceVisitStorageError.activeVisitAlreadyExists
            }

            nextVisits[record.id] = record

            expectedEvents[
                VisitEventKey(
                    visitID: record.id,
                    kind: .arrived
                )
            ] = record.startedAt
        }

        // MARK: - End Visits

        for record in update.endedVisits {

            guard let existing = nextVisits[record.id] else {
                throw PlaceVisitStorageError.visitNotFound
            }

            guard existing.isActive else {
                throw PlaceVisitStorageError.visitAlreadyEnded
            }

            guard let endedAt = record.endedAt,
                  endedAt.timeIntervalSince1970.isFinite,
                  endedAt >= existing.startedAt,
                  record.placeID == existing.placeID,
                  record.startedAt == existing.startedAt,
                  record.arrivalEvidence == existing.arrivalEvidence else {
                throw PlaceVisitStorageError.invalidVisitRecord
            }

            nextVisits[record.id] = record

            expectedEvents[
                VisitEventKey(
                    visitID: record.id,
                    kind: .departed
                )
            ] = endedAt
        }

        // MARK: - Validate Events

        guard update.events.count == expectedEvents.count else {
            throw PlaceVisitStorageError.invalidVisitEvent
        }

        for event in update.events {

            guard nextEvents[event.id] == nil else {
                throw PlaceVisitStorageError.duplicateEvent
            }

            guard let visit = nextVisits[event.visitID],
                  visit.placeID == event.placeID,
                  event.occurredAt.timeIntervalSince1970.isFinite else {
                throw PlaceVisitStorageError.invalidVisitEvent
            }

            let key = VisitEventKey(
                visitID: event.visitID,
                kind: event.kind
            )

            guard let expectedTime = expectedEvents.removeValue(
                forKey: key
            ),
            expectedTime == event.occurredAt else {
                throw PlaceVisitStorageError.invalidVisitEvent
            }

            let duplicateKind = nextEvents.values.contains {
                $0.visitID == event.visitID
                    && $0.kind == event.kind
            }

            guard !duplicateKind else {
                throw PlaceVisitStorageError.duplicateEvent
            }

            nextEvents[event.id] = event
        }

        guard expectedEvents.isEmpty else {
            throw PlaceVisitStorageError.invalidVisitEvent
        }

        // Commit the entire validated update.
        visits = nextVisits
        events = nextEvents
    }

    public func fetchAll() async throws -> [PlaceVisitRecord] {
        sortedVisits(
            Array(visits.values)
        )
    }

    public func fetchActiveVisits() async throws -> [PlaceVisitRecord] {
        sortedVisits(
            visits.values.filter(\.isActive)
        )
    }

    public func fetchEvents() async throws -> [PlaceVisitEvent] {
        events.values.sorted { lhs, rhs in

            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt < rhs.occurredAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

private extension InMemoryPlaceVisitStore {

    struct VisitEventKey: Hashable {
        let visitID: UUID
        let kind: PlaceVisitEvent.Kind
    }

    func sortedVisits(
        _ records: [PlaceVisitRecord]
    ) -> [PlaceVisitRecord] {

        records.sorted { lhs, rhs in

            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

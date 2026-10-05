//
//  InMemoryPlaceVisitStoreTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct InMemoryPlaceVisitStoreTests {

    @Test
    func initiallyContainsNoVisitsOrEvents() async throws {
        let store = InMemoryPlaceVisitStore()

        let visits = try await store.fetchAll()
        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(visits.isEmpty)
        #expect(activeVisits.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func savesArrivalAndActiveVisit() async throws {
        let store = InMemoryPlaceVisitStore()
        let record = makeVisit()

        try await store.apply(
            makeArrivalUpdate(record)
        )

        let visits = try await store.fetchAll()
        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(visits == [record])
        #expect(activeVisits == [record])
        #expect(events.count == 1)
        #expect(events.first?.kind == .arrived)
        #expect(events.first?.visitID == record.id)
        #expect(events.first?.placeID == record.placeID)
    }

    @Test
    func endsVisitWithoutChangingItsID() async throws {
        let store = InMemoryPlaceVisitStore()
        let record = makeVisit()

        try await store.apply(
            makeArrivalUpdate(record)
        )

        let endedRecord = record.ending(
            at: time(120)
        )

        try await store.apply(
            makeDepartureUpdate(endedRecord)
        )

        let visits = try await store.fetchAll()
        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(visits == [endedRecord])
        #expect(activeVisits.isEmpty)
        #expect(endedRecord.id == record.id)
        #expect(endedRecord.duration == 120)
        #expect(events.count == 2)
        #expect(events.map(\.kind) == [.arrived, .departed])
    }

    @Test
    func rejectsSecondActiveVisitAtSamePlace() async throws {
        let store = InMemoryPlaceVisitStore()
        let placeID = UUID()

        let first = makeVisit(
            placeID: placeID
        )

        let second = makeVisit(
            placeID: placeID,
            startedAt: time(60)
        )

        try await store.apply(
            makeArrivalUpdate(first)
        )

        await #expect(
            throws: PlaceVisitStorageError.activeVisitAlreadyExists
        ) {
            try await store.apply(
                makeArrivalUpdate(second)
            )
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits == [first])
        #expect(events.count == 1)
    }

    @Test
    func rejectsDuplicateVisit() async throws {
        let store = InMemoryPlaceVisitStore()
        let record = makeVisit()

        try await store.apply(
            makeArrivalUpdate(record)
        )

        await #expect(
            throws: PlaceVisitStorageError.duplicateVisit
        ) {
            try await store.apply(
                makeArrivalUpdate(record)
            )
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits.count == 1)
        #expect(events.count == 1)
    }

    @Test
    func rejectsDepartureForUnknownVisit() async throws {
        let store = InMemoryPlaceVisitStore()

        let endedRecord = makeVisit().ending(
            at: time(120)
        )

        await #expect(
            throws: PlaceVisitStorageError.visitNotFound
        ) {
            try await store.apply(
                makeDepartureUpdate(endedRecord)
            )
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func rejectsEndingVisitTwice() async throws {
        let store = InMemoryPlaceVisitStore()
        let record = makeVisit()

        try await store.apply(
            makeArrivalUpdate(record)
        )

        let endedRecord = record.ending(
            at: time(120)
        )

        try await store.apply(
            makeDepartureUpdate(endedRecord)
        )

        await #expect(
            throws: PlaceVisitStorageError.visitAlreadyEnded
        ) {
            try await store.apply(
                makeDepartureUpdate(endedRecord)
            )
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits == [endedRecord])
        #expect(events.count == 2)
    }

    @Test
    func rejectsEventWithIncorrectPlaceID() async throws {
        let store = InMemoryPlaceVisitStore()
        let record = makeVisit()

        let invalidEvent = PlaceVisitEvent(
            visitID: record.id,
            placeID: UUID(),
            kind: .arrived,
            occurredAt: record.startedAt
        )

        let update = PlaceVisitUpdate(
            events: [invalidEvent],
            startedVisits: [record]
        )

        await #expect(
            throws: PlaceVisitStorageError.invalidVisitEvent
        ) {
            try await store.apply(update)
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func failedBatchDoesNotPartiallySaveVisits() async throws {
        let store = InMemoryPlaceVisitStore()
        let placeID = UUID()

        let first = makeVisit(
            placeID: placeID
        )

        let second = makeVisit(
            placeID: placeID,
            startedAt: time(60)
        )

        let update = PlaceVisitUpdate(
            events: [
                makeArrivalEvent(first),
                makeArrivalEvent(second)
            ],
            startedVisits: [
                first,
                second
            ]
        )

        await #expect(
            throws: PlaceVisitStorageError.activeVisitAlreadyExists
        ) {
            try await store.apply(update)
        }

        let visits = try await store.fetchAll()
        let events = try await store.fetchEvents()

        #expect(visits.isEmpty)
        #expect(events.isEmpty)
    }

    @Test
    func atomicallyTransitionsActiveVisitToDifferentPlace()
        async throws {

        let store =
            InMemoryPlaceVisitStore()

        let home =
            makeVisit(
                placeID:
                    UUID()
            )

        try await store.apply(
            makeArrivalUpdate(
                home
            )
        )

        let endedHome =
            home.ending(
                at:
                    time(120)
            )

        let gym =
            makeVisit(
                placeID:
                    UUID(),
                startedAt:
                    time(120)
            )

        let update =
            PlaceVisitUpdate(
                events: [
                    PlaceVisitEvent(
                        visitID:
                            endedHome.id,
                        placeID:
                            endedHome.placeID,
                        kind:
                            .departed,
                        occurredAt:
                            time(120)
                    ),
                    PlaceVisitEvent(
                        visitID:
                            gym.id,
                        placeID:
                            gym.placeID,
                        kind:
                            .arrived,
                        occurredAt:
                            time(120)
                    )
                ],
                startedVisits: [
                    gym
                ],
                endedVisits: [
                    endedHome
                ]
            )

        try await store.apply(
            update
        )

        let activeVisits =
            try await store
                .fetchActiveVisits()

        #expect(
            activeVisits == [
                gym
            ]
        )

        let visits =
            try await store
                .fetchAll()

        #expect(
            visits.count == 2
        )

        #expect(
            visits.first {
                $0.id == home.id
            }?
            .endedAt
                == time(120)
        )

        let events =
            try await store
                .fetchEvents()

        #expect(
            events.count == 3
        )

        #expect(
            events.filter {
                $0.kind == .arrived
            }.count == 2
        )

        #expect(
            events.filter {
                $0.kind == .departed
            }.count == 1
        )

        #expect(
            events.contains {
                $0.visitID == endedHome.id
                    && $0.kind == .departed
                    && $0.occurredAt == time(120)
            }
        )

        #expect(
            events.contains {
                $0.visitID == gym.id
                    && $0.kind == .arrived
                    && $0.occurredAt == time(120)
            }
        )
    }
    
    @Test
    func rejectsSecondActiveVisitAtDifferentPlace()
        async throws {

        let store =
            InMemoryPlaceVisitStore()

        let home =
            makeVisit(
                placeID:
                    UUID()
            )

        let gym =
            makeVisit(
                placeID:
                    UUID(),
                startedAt:
                    time(60)
            )

        try await store.apply(
            makeArrivalUpdate(
                home
            )
        )

        await #expect(
            throws:
                PlaceVisitStorageError
                    .activeVisitAlreadyExists
        ) {

            try await store.apply(
                makeArrivalUpdate(
                    gym
                )
            )
        }

        let activeVisits =
            try await store
                .fetchActiveVisits()

        #expect(
            activeVisits == [
                home
            ]
        )
    }
    
    @Test
    func allowsNewVisitAfterPreviousVisitEnded() async throws {
        let store = InMemoryPlaceVisitStore()
        let placeID = UUID()

        let first = makeVisit(
            placeID: placeID
        )

        try await store.apply(
            makeArrivalUpdate(first)
        )

        let endedFirst = first.ending(
            at: time(120)
        )

        try await store.apply(
            makeDepartureUpdate(endedFirst)
        )

        let second = makeVisit(
            placeID: placeID,
            startedAt: time(180)
        )

        try await store.apply(
            makeArrivalUpdate(second)
        )

        let visits = try await store.fetchAll()
        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(visits.count == 2)
        #expect(activeVisits == [second])
        #expect(events.count == 3)
        #expect(first.id != second.id)
    }
}

// MARK: - Test Helpers

private extension InMemoryPlaceVisitStoreTests {

    func time(
        _ seconds: TimeInterval
    ) -> Date {
        Date(
            timeIntervalSince1970: 1_000_000 + seconds
        )
    }

    func makeVisit(
        placeID: UUID = UUID(),
        startedAt: Date? = nil
    ) -> PlaceVisitRecord {
        PlaceVisitRecord(
            placeID: placeID,
            startedAt: startedAt ?? time(0),
            arrivalEvidence: .bssid
        )
    }

    func makeArrivalEvent(
        _ record: PlaceVisitRecord
    ) -> PlaceVisitEvent {
        PlaceVisitEvent(
            visitID: record.id,
            placeID: record.placeID,
            kind: .arrived,
            occurredAt: record.startedAt
        )
    }

    func makeArrivalUpdate(
        _ record: PlaceVisitRecord
    ) -> PlaceVisitUpdate {
        PlaceVisitUpdate(
            events: [
                makeArrivalEvent(record)
            ],
            startedVisits: [
                record
            ]
        )
    }

    func makeDepartureUpdate(
        _ record: PlaceVisitRecord
    ) -> PlaceVisitUpdate {
        precondition(
            record.endedAt != nil,
            "A departure update requires an ended visit."
        )

        return PlaceVisitUpdate(
            events: [
                PlaceVisitEvent(
                    visitID: record.id,
                    placeID: record.placeID,
                    kind: .departed,
                    occurredAt: record.endedAt!
                )
            ],
            endedVisits: [
                record
            ]
        )
    }
}

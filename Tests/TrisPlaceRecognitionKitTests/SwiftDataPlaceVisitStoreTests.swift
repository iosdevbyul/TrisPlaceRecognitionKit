//
//  SwiftDataPlaceVisitStoreTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation
import SwiftData
import Testing

@testable import TrisPlaceRecognitionKit

struct SwiftDataPlaceVisitStoreTests {

    @available(iOS 17.0, *)
    @Test
    func initiallyContainsNoVisitsOrEvents() async throws {

        let store = try makeStore()

        let visits = try await store.fetchAll()
        let activeVisits = try await store.fetchActiveVisits()
        let events = try await store.fetchEvents()

        #expect(visits.isEmpty)
        #expect(activeVisits.isEmpty)
        #expect(events.isEmpty)
    }

    @available(iOS 17.0, *)
    @Test
    func savesArrivalAndActiveVisit() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func endsVisitWithoutChangingItsID() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func rejectsSecondActiveVisitAtSamePlace() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func rejectsDuplicateVisit() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func rejectsDepartureForUnknownVisit() async throws {

        let store = try makeStore()

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

        #expect(try await store.fetchAll().isEmpty)
        #expect(try await store.fetchEvents().isEmpty)
    }

    @available(iOS 17.0, *)
    @Test
    func rejectsInvalidEventWithoutSavingVisit() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func failedBatchDoesNotPartiallySaveVisits() async throws {

        let store = try makeStore()
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

    @available(iOS 17.0, *)
    @Test
    func allowsNewVisitAfterPreviousVisitEnded() async throws {

        let store = try makeStore()
        let placeID = UUID()

        let first = makeVisit(
            placeID: placeID
        )

        try await store.apply(
            makeArrivalUpdate(first)
        )

        try await store.apply(
            makeDepartureUpdate(
                first.ending(at: time(120))
            )
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

    @available(iOS 17.0, *)
    @Test
    func atomicallyTransitionsActiveVisitToDifferentPlace()
        async throws {

        let store =
            try makeStore()

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
    }
    
    @available(iOS 17.0, *)
    @Test
    func rejectsSecondActiveVisitAtDifferentPlace()
        async throws {

        let store =
            try makeStore()

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
    
    @available(iOS 17.0, *)
    @Test
    func persistsCompletedVisitAfterReopeningDatabase() async throws {

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: directoryURL
            )
        }

        let databaseURL = directoryURL
            .appendingPathComponent("visits.sqlite")

        let record = makeVisit()

        let endedRecord = record.ending(
            at: time(120)
        )

        // First launch: save the visit and its events.
        do {
            let store = try makeStore(
                databaseURL: databaseURL
            )

            try await store.apply(
                makeArrivalUpdate(record)
            )

            try await store.apply(
                makeDepartureUpdate(endedRecord)
            )
        }

        // Second launch: open a new ModelContainer
        // using the same SQLite database.
        do {
            let store = try makeStore(
                databaseURL: databaseURL
            )

            let visits = try await store.fetchAll()
            let activeVisits = try await store.fetchActiveVisits()
            let events = try await store.fetchEvents()

            #expect(visits == [endedRecord])
            #expect(activeVisits.isEmpty)

            #expect(events.count == 2)
            #expect(events.map(\.kind) == [.arrived, .departed])

            #expect(events.allSatisfy {
                $0.visitID == record.id
            })
        }
    }

    @available(iOS 17.0, *)
    @Test
    func restoresActiveVisitAfterReopeningDatabase() async throws {

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        defer {
            try? FileManager.default.removeItem(
                at: directoryURL
            )
        }

        let databaseURL = directoryURL
            .appendingPathComponent("active-visits.sqlite")

        let record = makeVisit()

        do {
            let store = try makeStore(
                databaseURL: databaseURL
            )

            try await store.apply(
                makeArrivalUpdate(record)
            )
        }

        do {
            let store = try makeStore(
                databaseURL: databaseURL
            )

            let visits = try await store.fetchAll()
            let activeVisits = try await store.fetchActiveVisits()
            let events = try await store.fetchEvents()

            #expect(visits == [record])
            #expect(activeVisits == [record])

            #expect(events.count == 1)
            #expect(events.first?.kind == .arrived)
        }
    }
}

// MARK: - Test Helpers

@available(iOS 17.0, *)
private extension SwiftDataPlaceVisitStoreTests {

    func makeStore(
        databaseURL: URL? = nil
    ) throws -> SwiftDataPlaceVisitStore {

        let schema = Schema([
            StoredPlaceVisit.self,
            StoredPlaceVisitEvent.self
        ])

        let configuration: ModelConfiguration

        if let databaseURL {
            configuration = ModelConfiguration(
                schema: schema,
                url: databaseURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        }

        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        return SwiftDataPlaceVisitStore(
            modelContainer: container
        )
    }

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

        guard let endedAt = record.endedAt else {
            preconditionFailure(
                "Departure requires an ended visit."
            )
        }

        return PlaceVisitUpdate(
            events: [
                PlaceVisitEvent(
                    visitID: record.id,
                    placeID: record.placeID,
                    kind: .departed,
                    occurredAt: endedAt
                )
            ],
            endedVisits: [
                record
            ]
        )
    }
}

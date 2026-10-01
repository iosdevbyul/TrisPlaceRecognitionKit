//
//  PlaceVisitManagerQueryTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceVisitManagerQueryTests {

    @Test
    func fetchVisitsReturnsAllVisitsChronologically() async throws {

        let store = InMemoryPlaceVisitStore()

        let first = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(0),
            endedAt: time(30)
        )

        let second = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(60),
            endedAt: time(90)
        )

        let manager = makeManager(
            visitStore: store
        )

        let visits = try await manager.fetchVisits()

        #expect(
            visits == [
                first,
                second
            ]
        )
    }

    @Test
    func fetchVisitsForPlaceFiltersOtherPlaces() async throws {

        let store = InMemoryPlaceVisitStore()

        let gymID = UUID()
        let homeID = UUID()

        let firstGymVisit = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(0),
            endedAt: time(30)
        )

        _ = try await saveCompletedVisit(
            to: store,
            placeID: homeID,
            startedAt: time(60),
            endedAt: time(90)
        )

        let secondGymVisit = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(120),
            endedAt: time(150)
        )

        let manager = makeManager(
            visitStore: store
        )

        let visits = try await manager.fetchVisits(
            for: gymID
        )

        #expect(
            visits == [
                firstGymVisit,
                secondGymVisit
            ]
        )
    }

    @Test
    func fetchVisitsInRangeIncludesOverlappingVisits() async throws {

        let store = InMemoryPlaceVisitStore()

        let before = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(0),
            endedAt: time(40)
        )

        let overlapsStart = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(50),
            endedAt: time(120)
        )

        let inside = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(130),
            endedAt: time(150)
        )

        let active = try await saveActiveVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(190)
        )

        let after = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(210),
            endedAt: time(240)
        )

        let manager = makeManager(
            visitStore: store
        )

        let visits = try await manager.fetchVisits(
            from: time(100),
            to: time(200)
        )

        #expect(
            visits == [
                overlapsStart,
                inside,
                active
            ]
        )

        #expect(
            !visits.contains(before)
        )

        #expect(
            !visits.contains(after)
        )
    }

    @Test
    func fetchVisitsForPlaceWithinRangeCombinesFilters() async throws {

        let store = InMemoryPlaceVisitStore()

        let gymID = UUID()
        let homeID = UUID()

        let oldGymVisit = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(0),
            endedAt: time(30)
        )

        let matchingGymVisit = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(100),
            endedAt: time(160)
        )

        let homeVisit = try await saveCompletedVisit(
            to: store,
            placeID: homeID,
            startedAt: time(120),
            endedAt: time(180)
        )

        let manager = makeManager(
            visitStore: store
        )

        let visits = try await manager.fetchVisits(
            for: gymID,
            from: time(90),
            to: time(200)
        )

        #expect(
            visits == [
                matchingGymVisit
            ]
        )

        #expect(
            !visits.contains(oldGymVisit)
        )

        #expect(
            !visits.contains(homeVisit)
        )
    }

    @Test
    func fetchLatestVisitReturnsNewestVisitForPlace() async throws {

        let store = InMemoryPlaceVisitStore()

        let gymID = UUID()
        let homeID = UUID()

        _ = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(0),
            endedAt: time(30)
        )

        let latestGymVisit = try await saveCompletedVisit(
            to: store,
            placeID: gymID,
            startedAt: time(120),
            endedAt: time(180)
        )

        _ = try await saveCompletedVisit(
            to: store,
            placeID: homeID,
            startedAt: time(240),
            endedAt: time(300)
        )

        let manager = makeManager(
            visitStore: store
        )

        let latest = try await manager.fetchLatestVisit(
            for: gymID
        )

        #expect(
            latest == latestGymVisit
        )
    }

    @Test
    func fetchLatestVisitReturnsNilForUnknownPlace() async throws {

        let store = InMemoryPlaceVisitStore()

        _ = try await saveCompletedVisit(
            to: store,
            placeID: UUID(),
            startedAt: time(0),
            endedAt: time(30)
        )

        let manager = makeManager(
            visitStore: store
        )

        let latest = try await manager.fetchLatestVisit(
            for: UUID()
        )

        #expect(
            latest == nil
        )
    }

    @Test
    func rejectsInvalidDateRange() async throws {

        let store = InMemoryPlaceVisitStore()

        let manager = makeManager(
            visitStore: store
        )

        await #expect(
            throws: PlaceVisitQueryError.invalidDateRange
        ) {
            _ = try await manager.fetchVisits(
                from: time(200),
                to: time(100)
            )
        }
    }

    @Test
    func fetchEventsReturnsEventsChronologically() async throws {

        let store = InMemoryPlaceVisitStore()

        let placeID = UUID()

        let first = try await saveCompletedVisit(
            to: store,
            placeID: placeID,
            startedAt: time(0),
            endedAt: time(30)
        )

        let second = try await saveCompletedVisit(
            to: store,
            placeID: placeID,
            startedAt: time(60),
            endedAt: time(90)
        )

        let manager = makeManager(
            visitStore: store
        )

        let events = try await manager.fetchEvents()

        #expect(events.count == 4)

        #expect(
            events.map(\.kind) == [
                .arrived,
                .departed,
                .arrived,
                .departed
            ]
        )

        #expect(
            events[0].visitID == first.id
        )

        #expect(
            events[1].visitID == first.id
        )

        #expect(
            events[2].visitID == second.id
        )

        #expect(
            events[3].visitID == second.id
        )
    }
}

private extension PlaceVisitManagerQueryTests {

    func makeManager(
        visitStore: any PlaceVisitStoring
    ) -> PlaceVisitManager {

        let recognitionService = PlaceRecognitionService(
            locationProvider: MockLocationProvider(),
            wifiProvider: MockWiFiProvider(),
            placeStore: MockPlaceStore()
        )

        return PlaceVisitManager(
            recognitionService: recognitionService,
            visitStore: visitStore
        )
    }

    func time(
        _ seconds: TimeInterval
    ) -> Date {

        Date(
            timeIntervalSince1970:
                1_000_000 + seconds
        )
    }

    func saveActiveVisit(
        to store: InMemoryPlaceVisitStore,
        placeID: UUID,
        startedAt: Date
    ) async throws -> PlaceVisitRecord {

        let record = PlaceVisitRecord(
            placeID: placeID,
            startedAt: startedAt,
            arrivalEvidence: .bssid
        )

        let event = PlaceVisitEvent(
            visitID: record.id,
            placeID: record.placeID,
            kind: .arrived,
            occurredAt: record.startedAt
        )

        try await store.apply(
            PlaceVisitUpdate(
                events: [
                    event
                ],
                startedVisits: [
                    record
                ]
            )
        )

        return record
    }

    func saveCompletedVisit(
        to store: InMemoryPlaceVisitStore,
        placeID: UUID,
        startedAt: Date,
        endedAt: Date
    ) async throws -> PlaceVisitRecord {

        let active = try await saveActiveVisit(
            to: store,
            placeID: placeID,
            startedAt: startedAt
        )

        let completed = active.ending(
            at: endedAt
        )

        let event = PlaceVisitEvent(
            visitID: completed.id,
            placeID: completed.placeID,
            kind: .departed,
            occurredAt: completed.endedAt!
        )

        try await store.apply(
            PlaceVisitUpdate(
                events: [
                    event
                ],
                endedVisits: [
                    completed
                ]
            )
        )

        return completed
    }
}

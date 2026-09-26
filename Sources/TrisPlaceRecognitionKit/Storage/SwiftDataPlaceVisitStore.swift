//
//  SwiftDataPlaceVisitStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-27.
//

import Foundation
import SwiftData

@available(iOS 17.0, *)
public actor SwiftDataPlaceVisitStore: PlaceVisitStoring {

    private let modelContainer: ModelContainer

    public init(
        modelContainer: ModelContainer
    ) {
        self.modelContainer = modelContainer
    }

    public init() throws {
        let schema = Schema([
            StoredPlaceVisit.self,
            StoredPlaceVisitEvent.self
        ])

        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directoryURL = applicationSupportURL
            .appendingPathComponent(
                "TrisPlaceRecognitionKit",
                isDirectory: true
            )

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let databaseURL = directoryURL
            .appendingPathComponent("place-visits.sqlite")

        let configuration = ModelConfiguration(
            schema: schema,
            url: databaseURL,
            cloudKitDatabase: .none
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    public func apply(
        _ update: PlaceVisitUpdate
    ) async throws {

        if update.events.isEmpty,
           update.startedVisits.isEmpty,
           update.endedVisits.isEmpty {
            return
        }

        let context = ModelContext(modelContainer)

        let storedVisits = try context.fetch(
            FetchDescriptor<StoredPlaceVisit>()
        )

        let storedEvents = try context.fetch(
            FetchDescriptor<StoredPlaceVisitEvent>()
        )

        var visitModelsByID: [UUID: StoredPlaceVisit] = [:]
        var nextVisits: [UUID: PlaceVisitRecord] = [:]

        for model in storedVisits {
            let record = try makeVisitRecord(from: model)

            guard nextVisits[record.id] == nil else {
                throw PlaceVisitStorageError.duplicateVisit
            }

            visitModelsByID[record.id] = model
            nextVisits[record.id] = record
        }

        var existingEventIDs = Set<UUID>()
        var existingEventKeys = Set<VisitEventKey>()

        for model in storedEvents {
            let event = try makeVisitEvent(from: model)

            guard existingEventIDs.insert(event.id).inserted else {
                throw PlaceVisitStorageError.duplicateEvent
            }

            let key = VisitEventKey(
                visitID: event.visitID,
                kindRawValue: event.kind.rawValue
            )

            guard existingEventKeys.insert(key).inserted else {
                throw PlaceVisitStorageError.duplicateEvent
            }
        }

        var expectedEvents: [VisitEventKey: Date] = [:]

        // MARK: - Validate Started Visits

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

            let key = VisitEventKey(
                visitID: record.id,
                kindRawValue: PlaceVisitEvent.Kind.arrived.rawValue
            )

            expectedEvents[key] = record.startedAt
        }

        // MARK: - Validate Ended Visits

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

            let key = VisitEventKey(
                visitID: record.id,
                kindRawValue: PlaceVisitEvent.Kind.departed.rawValue
            )

            expectedEvents[key] = endedAt
        }

        // MARK: - Validate Events

        guard update.events.count == expectedEvents.count else {
            throw PlaceVisitStorageError.invalidVisitEvent
        }

        var nextEventIDs = existingEventIDs
        var nextEventKeys = existingEventKeys

        for event in update.events {

            guard nextEventIDs.insert(event.id).inserted else {
                throw PlaceVisitStorageError.duplicateEvent
            }

            guard let visit = nextVisits[event.visitID],
                  visit.placeID == event.placeID,
                  event.occurredAt.timeIntervalSince1970.isFinite else {
                throw PlaceVisitStorageError.invalidVisitEvent
            }

            let key = VisitEventKey(
                visitID: event.visitID,
                kindRawValue: event.kind.rawValue
            )

            guard let expectedTime = expectedEvents.removeValue(
                forKey: key
            ),
            expectedTime == event.occurredAt else {
                throw PlaceVisitStorageError.invalidVisitEvent
            }

            guard nextEventKeys.insert(key).inserted else {
                throw PlaceVisitStorageError.duplicateEvent
            }
        }

        guard expectedEvents.isEmpty else {
            throw PlaceVisitStorageError.invalidVisitEvent
        }

        // MARK: - Persist Validated Updates

        // No SwiftData model is inserted or modified
        // until the entire update passes validation.

        for record in update.startedVisits {

            let model = StoredPlaceVisit(
                id: record.id,
                placeID: record.placeID,
                startedAt: record.startedAt,
                endedAt: nil,
                arrivalEvidenceRawValue: evidenceRawValue(
                    record.arrivalEvidence
                )
            )

            context.insert(model)

            visitModelsByID[record.id] = model
        }

        for record in update.endedVisits {

            guard let model = visitModelsByID[record.id] else {
                throw PlaceVisitStorageError.visitNotFound
            }

            model.endedAt = record.endedAt
        }

        for event in update.events {

            let model = StoredPlaceVisitEvent(
                id: event.id,
                visitID: event.visitID,
                placeID: event.placeID,
                kindRawValue: event.kind.rawValue,
                occurredAt: event.occurredAt
            )

            context.insert(model)
        }

        // Save visit records and events together.
        try context.save()
    }

    public func fetchAll() async throws -> [PlaceVisitRecord] {

        let context = ModelContext(modelContainer)

        let models = try context.fetch(
            FetchDescriptor<StoredPlaceVisit>()
        )

        let records = try models.map {
            try makeVisitRecord(from: $0)
        }

        return sortedVisits(records)
    }

    public func fetchActiveVisits() async throws -> [PlaceVisitRecord] {

        let context = ModelContext(modelContainer)

        let models = try context.fetch(
            FetchDescriptor<StoredPlaceVisit>()
        )

        let records = try models.map {
            try makeVisitRecord(from: $0)
        }

        return sortedVisits(
            records.filter(\.isActive)
        )
    }

    public func fetchEvents() async throws -> [PlaceVisitEvent] {

        let context = ModelContext(modelContainer)

        let models = try context.fetch(
            FetchDescriptor<StoredPlaceVisitEvent>()
        )

        let events = try models.map {
            try makeVisitEvent(from: $0)
        }

        return events.sorted { lhs, rhs in
            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt < rhs.occurredAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

@available(iOS 17.0, *)
private extension SwiftDataPlaceVisitStore {

    struct VisitEventKey: Hashable {
        let visitID: UUID
        let kindRawValue: String
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

    func evidenceRawValue(
        _ evidence: PlaceRecognitionEvidence
    ) -> String {

        switch evidence {

        case .bssid:
            return "bssid"

        case .ssid:
            return "ssid"

        case .gpsOnlyWiFiUnavailable:
            return "gpsOnlyWiFiUnavailable"

        case .gpsOnlyNoWiFiConfigured:
            return "gpsOnlyNoWiFiConfigured"
        }
    }

    func makeEvidence(
        from rawValue: String
    ) throws -> PlaceRecognitionEvidence {

        switch rawValue {

        case "bssid":
            return .bssid

        case "ssid":
            return .ssid

        case "gpsOnlyWiFiUnavailable":
            return .gpsOnlyWiFiUnavailable

        case "gpsOnlyNoWiFiConfigured":
            return .gpsOnlyNoWiFiConfigured

        default:
            throw PlaceVisitStorageError.invalidVisitRecord
        }
    }

    func makeVisitRecord(
        from model: StoredPlaceVisit
    ) throws -> PlaceVisitRecord {

        guard model.startedAt.timeIntervalSince1970.isFinite else {
            throw PlaceVisitStorageError.invalidVisitRecord
        }

        if let endedAt = model.endedAt {
            guard endedAt.timeIntervalSince1970.isFinite,
                  endedAt >= model.startedAt else {
                throw PlaceVisitStorageError.invalidVisitRecord
            }
        }

        let evidence = try makeEvidence(
            from: model.arrivalEvidenceRawValue
        )

        return PlaceVisitRecord(
            id: model.id,
            placeID: model.placeID,
            startedAt: model.startedAt,
            endedAt: model.endedAt,
            arrivalEvidence: evidence
        )
    }

    func makeVisitEvent(
        from model: StoredPlaceVisitEvent
    ) throws -> PlaceVisitEvent {

        guard let kind = PlaceVisitEvent.Kind(
            rawValue: model.kindRawValue
        ),
        model.occurredAt.timeIntervalSince1970.isFinite else {
            throw PlaceVisitStorageError.invalidVisitEvent
        }

        return PlaceVisitEvent(
            id: model.id,
            visitID: model.visitID,
            placeID: model.placeID,
            kind: kind,
            occurredAt: model.occurredAt
        )
    }
}

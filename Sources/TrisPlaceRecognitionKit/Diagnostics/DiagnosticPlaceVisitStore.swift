//
//  DiagnosticPlaceVisitStore.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-04.
//

import Foundation

actor DiagnosticPlaceVisitStore:
    PlaceVisitStoring {

    private let base:
        any PlaceVisitStoring

    private let diagnosticStore:
        any PlaceVisitDiagnosticStoring

    init(
        base:
            any PlaceVisitStoring,
        diagnosticStore:
            any PlaceVisitDiagnosticStoring
    ) {

        self.base =
            base

        self.diagnosticStore =
            diagnosticStore
    }

    func apply(
        _ update:
            PlaceVisitUpdate
    ) async throws {

        await log(
            category:
                .visit,
            name:
                "storage.apply.started",
            metadata: [
                "events":
                    "\(update.events.count)",
                "startedVisits":
                    "\(update.startedVisits.count)",
                "endedVisits":
                    "\(update.endedVisits.count)"
            ]
        )

        do {

            try await base
                .apply(
                    update
                )

            await log(
                category:
                    .visit,
                name:
                    "storage.apply.succeeded",
                metadata: [
                    "events":
                        "\(update.events.count)",
                    "startedVisits":
                        "\(update.startedVisits.count)",
                    "endedVisits":
                        "\(update.endedVisits.count)"
                ]
            )

        } catch {

            await log(
                category:
                    .error,
                name:
                    "storage.apply.failed",
                metadata: [
                    "error":
                        error.localizedDescription,
                    "errorType":
                        String(
                            reflecting:
                                type(
                                    of:
                                        error
                                )
                        ),
                    "events":
                        "\(update.events.count)",
                    "startedVisits":
                        "\(update.startedVisits.count)",
                    "endedVisits":
                        "\(update.endedVisits.count)"
                ]
            )

            throw error
        }
    }

    func fetchAll()
        async throws
        -> [PlaceVisitRecord] {

        await log(
            category:
                .visit,
            name:
                "storage.fetchAll.started"
        )

        do {

            let visits =
                try await base
                    .fetchAll()

            await log(
                category:
                    .visit,
                name:
                    "storage.fetchAll.succeeded",
                metadata: [
                    "count":
                        "\(visits.count)"
                ]
            )

            return visits

        } catch {

            await logFailure(
                name:
                    "storage.fetchAll.failed",
                error:
                    error
            )

            throw error
        }
    }

    func fetchActiveVisits()
        async throws
        -> [PlaceVisitRecord] {

        await log(
            category:
                .visit,
            name:
                "storage.fetchActiveVisits.started"
        )

        do {

            let visits =
                try await base
                    .fetchActiveVisits()

            await log(
                category:
                    .visit,
                name:
                    "storage.fetchActiveVisits.succeeded",
                metadata: [
                    "count":
                        "\(visits.count)"
                ]
            )

            return visits

        } catch {

            await logFailure(
                name:
                    "storage.fetchActiveVisits.failed",
                error:
                    error
            )

            throw error
        }
    }

    func fetchEvents()
        async throws
        -> [PlaceVisitEvent] {

        await log(
            category:
                .visit,
            name:
                "storage.fetchEvents.started"
        )

        do {

            let events =
                try await base
                    .fetchEvents()

            await log(
                category:
                    .visit,
                name:
                    "storage.fetchEvents.succeeded",
                metadata: [
                    "count":
                        "\(events.count)"
                ]
            )

            return events

        } catch {

            await logFailure(
                name:
                    "storage.fetchEvents.failed",
                error:
                    error
            )

            throw error
        }
    }
}

private extension DiagnosticPlaceVisitStore {

    func logFailure(
        name:
            String,
        error:
            Error
    ) async {

        await log(
            category:
                .error,
            name:
                name,
            metadata: [
                "error":
                    error.localizedDescription,
                "errorType":
                    String(
                        reflecting:
                            type(
                                of:
                                    error
                            )
                    )
            ]
        )
    }

    func log(
        category:
            PlaceVisitDiagnosticCategory,
        name:
            String,
        metadata:
            [String: String] = [:]
    ) async {

        let event =
            PlaceVisitDiagnosticEvent(
                category:
                    category,
                name:
                    name,
                metadata:
                    metadata
            )

        do {

            try await diagnosticStore
                .append(
                    event
                )

        } catch {

            // Diagnostic logging must never affect
            // visit persistence or queries.
        }
    }
}

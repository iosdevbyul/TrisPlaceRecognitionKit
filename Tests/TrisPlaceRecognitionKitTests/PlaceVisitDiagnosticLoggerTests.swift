//
//  PlaceVisitDiagnosticLoggerTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-04.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceVisitDiagnosticLoggerTests {

    @Test
    func appendsAndRestoresEvents()
        async throws {

        let fileURL =
            makeTemporaryFileURL()

        let logger =
            FilePlaceVisitDiagnosticLogger(
                fileURL: fileURL
            )

        let event =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_000
                    ),
                category:
                    .regionEvent,
                name:
                    "region.entered",
                placeID:
                    UUID(
                        uuidString:
                            "11111111-1111-1111-1111-111111111111"
                    ),
                metadata: [
                    "source":
                        "coreLocation"
                ]
            )

        try await logger.append(
            event
        )

        let restoredLogger =
            FilePlaceVisitDiagnosticLogger(
                fileURL: fileURL
            )

        let restoredEvents =
            try await restoredLogger
                .fetchAll()

        #expect(
            restoredEvents
                == [
                    event
                ]
        )
    }

    @Test
    func preservesEventOrder()
        async throws {

        let fileURL =
            makeTemporaryFileURL()

        let logger =
            FilePlaceVisitDiagnosticLogger(
                fileURL: fileURL
            )

        let first =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_000
                    ),
                category:
                    .lifecycle,
                name:
                    "background.started"
            )

        let second =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            2_000
                    ),
                category:
                    .regionEvent,
                name:
                    "region.entered"
            )

        try await logger.append(
            first
        )

        try await logger.append(
            second
        )

        let events =
            try await logger.fetchAll()

        #expect(
            events
                == [
                    first,
                    second
                ]
        )
    }

    @Test
    func trimsOldestEventsWhenLimitIsExceeded()
        async throws {

        let fileURL =
            makeTemporaryFileURL()

        let logger =
            FilePlaceVisitDiagnosticLogger(
                fileURL: fileURL,
                maximumEventCount: 2
            )

        let first =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_000
                    ),
                category:
                    .lifecycle,
                name:
                    "first"
            )

        let second =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            2_000
                    ),
                category:
                    .lifecycle,
                name:
                    "second"
            )

        let third =
            PlaceVisitDiagnosticEvent(
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            3_000
                    ),
                category:
                    .lifecycle,
                name:
                    "third"
            )

        try await logger.append(
            first
        )

        try await logger.append(
            second
        )

        try await logger.append(
            third
        )

        let events =
            try await logger.fetchAll()

        #expect(
            events
                == [
                    second,
                    third
                ]
        )
    }

    @Test
    func clearRemovesPersistedEvents()
        async throws {

        let fileURL =
            makeTemporaryFileURL()

        let logger =
            FilePlaceVisitDiagnosticLogger(
                fileURL: fileURL
            )

        try await logger.append(
            PlaceVisitDiagnosticEvent(
                category:
                    .recognition,
                name:
                    "recognition.started"
            )
        )

        try await logger.clear()

        let events =
            try await logger.fetchAll()

        #expect(
            events.isEmpty
        )

        #expect(
            !FileManager.default
                .fileExists(
                    atPath:
                        fileURL.path
                )
        )
    }
}

private extension
    PlaceVisitDiagnosticLoggerTests {

    func makeTemporaryFileURL()
        -> URL {

        FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                UUID()
                    .uuidString
            )
            .appendingPathExtension(
                "jsonl"
            )
    }
}

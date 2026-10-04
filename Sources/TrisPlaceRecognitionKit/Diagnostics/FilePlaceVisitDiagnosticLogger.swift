//
//  FilePlaceVisitDiagnosticLogger.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-04.
//

import Foundation

actor FilePlaceVisitDiagnosticLogger:
    PlaceVisitDiagnosticStoring {

    private let fileURL: URL
    private let maximumEventCount: Int

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL? = nil,
        maximumEventCount: Int = 500
    ) {

        self.maximumEventCount =
            max(
                1,
                maximumEventCount
            )

        let encoder =
            JSONEncoder()

        encoder.dateEncodingStrategy =
            .iso8601

        self.encoder =
            encoder

        let decoder =
            JSONDecoder()

        decoder.dateDecodingStrategy =
            .iso8601

        self.decoder =
            decoder

        if let fileURL {

            self.fileURL =
                fileURL

        } else {

            self.fileURL =
                Self.makeDefaultFileURL()
        }
    }

    func append(
        _ event: PlaceVisitDiagnosticEvent
    ) async throws {

        var events =
            try readEvents()

        events.append(
            event
        )

        if events.count
            > maximumEventCount {

            events =
                Array(
                    events.suffix(
                        maximumEventCount
                    )
                )
        }

        try writeEvents(
            events
        )
    }

    func fetchAll()
        async throws
        -> [PlaceVisitDiagnosticEvent] {

        try readEvents()
    }

    func clear()
        async throws {

        let fileManager =
            FileManager.default

        guard
            fileManager.fileExists(
                atPath:
                    fileURL.path
            )
        else {
            return
        }

        try fileManager.removeItem(
            at: fileURL
        )
    }
}

private extension
    FilePlaceVisitDiagnosticLogger {

    static func makeDefaultFileURL()
        -> URL {

        let fileManager =
            FileManager.default

        let applicationSupportURL =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )
            .first
            ?? fileManager
                .temporaryDirectory

        let directoryURL =
            applicationSupportURL
                .appendingPathComponent(
                    "TrisPlaceRecognitionKit",
                    isDirectory: true
                )

        return directoryURL
            .appendingPathComponent(
                "place-visit-diagnostics.jsonl"
            )
    }

    func readEvents()
        throws
        -> [PlaceVisitDiagnosticEvent] {

        let fileManager =
            FileManager.default

        guard
            fileManager.fileExists(
                atPath:
                    fileURL.path
            )
        else {
            return []
        }

        let data =
            try Data(
                contentsOf: fileURL
            )

        guard !data.isEmpty else {
            return []
        }

        guard
            let text =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return []
        }

        return try text
            .split(
                separator: "\n"
            )
            .map { line in

                let data =
                    Data(
                        line.utf8
                    )

                return try decoder
                    .decode(
                        PlaceVisitDiagnosticEvent.self,
                        from: data
                    )
            }
    }

    func writeEvents(
        _ events:
            [PlaceVisitDiagnosticEvent]
    ) throws {

        let fileManager =
            FileManager.default

        let directoryURL =
            fileURL
                .deletingLastPathComponent()

        try fileManager
            .createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

        let lines =
            try events.map { event in

                let data =
                    try encoder.encode(
                        event
                    )

                guard
                    let string =
                        String(
                            data: data,
                            encoding: .utf8
                        )
                else {
                    throw CocoaError(
                        .fileWriteInapplicableStringEncoding
                    )
                }

                return string
            }

        let text =
            lines.joined(
                separator: "\n"
            )
            + (
                lines.isEmpty
                ? ""
                : "\n"
            )

        let data =
            Data(
                text.utf8
            )

        try data.write(
            to: fileURL,
            options: .atomic
        )
    }
}

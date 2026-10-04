//
//  PlaceVisitDiagnosticEvent.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-04.
//

import Foundation

public enum PlaceVisitDiagnosticCategory:
    String,
    Codable,
    Sendable,
    Equatable {

    case lifecycle
    case authorization
    case regionSync
    case regionEvent
    case recognition
    case visit
    case error
}

public struct PlaceVisitDiagnosticEvent:
    Identifiable,
    Codable,
    Sendable,
    Equatable {

    public let id: UUID
    public let timestamp: Date
    public let category: PlaceVisitDiagnosticCategory
    public let name: String
    public let placeID: UUID?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: PlaceVisitDiagnosticCategory,
        name: String,
        placeID: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.name = name
        self.placeID = placeID
        self.metadata = metadata
    }
}

protocol PlaceVisitDiagnosticStoring:
    Sendable {

    func append(
        _ event: PlaceVisitDiagnosticEvent
    ) async throws

    func fetchAll()
        async throws
        -> [PlaceVisitDiagnosticEvent]

    func clear()
        async throws
}

struct NoOpPlaceVisitDiagnosticStore:
    PlaceVisitDiagnosticStoring {

    func append(
        _ event: PlaceVisitDiagnosticEvent
    ) async throws {
    }

    func fetchAll()
        async throws
        -> [PlaceVisitDiagnosticEvent] {

        []
    }

    func clear()
        async throws {
    }
}

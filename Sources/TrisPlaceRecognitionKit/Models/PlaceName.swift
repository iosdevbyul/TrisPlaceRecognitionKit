//
//  PlaceName.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//


import Foundation

public struct PlaceName: Sendable,
                         Equatable,
                         Hashable,
                         Codable {

    public static let maximumLength = 10

    public let value: String

    public init(_ value: String) throws {
        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedValue.isEmpty else {
            throw PlaceRegistrationError.emptyName
        }

        guard trimmedValue.count <= Self.maximumLength else {
            throw PlaceRegistrationError.nameTooLong
        }

        self.value = trimmedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid place name: \(error)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

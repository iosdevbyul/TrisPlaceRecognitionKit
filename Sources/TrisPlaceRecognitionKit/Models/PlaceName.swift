//
//  PlaceName.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation

public struct PlaceName: Sendable, Equatable, Hashable {

    public static let maximumLength = 10

    public let value: String

    public init(
        _ value: String
    ) throws {
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
}

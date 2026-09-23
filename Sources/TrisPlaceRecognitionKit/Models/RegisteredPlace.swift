//
//  RegisteredPlace.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation

public struct RegisteredPlace: Identifiable,
                               Sendable,
                               Equatable,
                               Hashable,
                               Codable {

    public let id: UUID

    public var name: PlaceName

    public let location: PlaceLocation

    public let networkIdentity: PlaceNetworkIdentity

    public init(
        id: UUID = UUID(),
        name: PlaceName,
        location: PlaceLocation,
        networkIdentity: PlaceNetworkIdentity
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.networkIdentity = networkIdentity
    }
}

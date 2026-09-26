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

    // Preserve compatibility with existing places.
    public let networkIdentity: PlaceNetworkIdentity

    public let additionalNetworkIdentities: [PlaceNetworkIdentity]

    public var networkIdentities: [PlaceNetworkIdentity] {
        ([networkIdentity] + additionalNetworkIdentities)
            .filter { identity in
                let hasSSID = identity.ssid.map {
                    !$0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                } ?? false

                let hasBSSID = identity.bssid.map {
                    !$0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                } ?? false

                return hasSSID || hasBSSID
            }
    }

    public init(
        id: UUID = UUID(),
        name: PlaceName,
        location: PlaceLocation,
        networkIdentity: PlaceNetworkIdentity,
        additionalNetworkIdentities: [PlaceNetworkIdentity] = []
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.networkIdentity = networkIdentity
        self.additionalNetworkIdentities = additionalNetworkIdentities
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case networkIdentity
        case additionalNetworkIdentities
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        id = try container.decode(
            UUID.self,
            forKey: .id
        )

        name = try container.decode(
            PlaceName.self,
            forKey: .name
        )

        location = try container.decode(
            PlaceLocation.self,
            forKey: .location
        )

        networkIdentity = try container.decode(
            PlaceNetworkIdentity.self,
            forKey: .networkIdentity
        )

        additionalNetworkIdentities = try container.decodeIfPresent(
            [PlaceNetworkIdentity].self,
            forKey: .additionalNetworkIdentities
        ) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(location, forKey: .location)

        try container.encode(
            networkIdentity,
            forKey: .networkIdentity
        )

        if !additionalNetworkIdentities.isEmpty {
            try container.encode(
                additionalNetworkIdentities,
                forKey: .additionalNetworkIdentities
            )
        }
    }
}

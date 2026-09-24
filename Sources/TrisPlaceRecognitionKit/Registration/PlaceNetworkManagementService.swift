//
//  PlaceNetworkManagementService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation

@MainActor
public final class PlaceNetworkManagementService {

    private let placeStore: any PlaceStoring
    private let wifiProvider: any WiFiProviding

    public init(
        placeStore: any PlaceStoring,
        wifiProvider: any WiFiProviding
    ) {
        self.placeStore = placeStore
        self.wifiProvider = wifiProvider
    }

    public func addCurrentNetwork(
        to placeID: UUID
    ) async throws -> RegisteredPlace {
        let place = try await findPlace(id: placeID)

        guard let current = await wifiProvider.currentNetwork(),
              !current.ssid.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
            throw PlaceNetworkManagementError.currentWiFiUnavailable
        }

        let bssid = current.bssid?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let identity = PlaceNetworkIdentity(
            ssid: current.ssid,
            bssid: bssid?.isEmpty == false ? bssid : nil
        )

        var networks = place.networkIdentities

        // Re-registering the same access point is idempotent.
        if networks.contains(where: {
            isSameNetwork($0, identity)
        }) {
            return place
        }

        networks.append(identity)

        return try await save(
            place: place,
            networks: networks
        )
    }

    public func removeNetwork(
        _ network: PlaceNetworkIdentity,
        from placeID: UUID
    ) async throws -> RegisteredPlace {
        let place = try await findPlace(id: placeID)

        var networks = place.networkIdentities

        guard let index = networks.firstIndex(where: {
            isSameNetwork($0, network)
        }) else {
            throw PlaceNetworkManagementError.networkNotRegistered
        }

        networks.remove(at: index)

        return try await save(
            place: place,
            networks: networks
        )
    }
}

private extension PlaceNetworkManagementService {

    func findPlace(
        id: UUID
    ) async throws -> RegisteredPlace {
        let places = try await placeStore.fetchAll()

        guard let place = places.first(where: {
            $0.id == id
        }) else {
            throw PlaceNetworkManagementError.placeNotFound(id)
        }

        return place
    }

    func save(
        place: RegisteredPlace,
        networks: [PlaceNetworkIdentity]
    ) async throws -> RegisteredPlace {
        let primary = networks.first
            ?? PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )

        let updated = RegisteredPlace(
            id: place.id,
            name: place.name,
            location: place.location,
            networkIdentity: primary,
            additionalNetworkIdentities: Array(
                networks.dropFirst()
            )
        )

        try await placeStore.save(updated)

        return updated
    }

    func isSameNetwork(
        _ lhs: PlaceNetworkIdentity,
        _ rhs: PlaceNetworkIdentity
    ) -> Bool {
        let lhsBSSID = lhs.bssid?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let rhsBSSID = rhs.bssid?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if let lhsBSSID,
           !lhsBSSID.isEmpty,
           let rhsBSSID,
           !rhsBSSID.isEmpty {
            return lhsBSSID.caseInsensitiveCompare(
                rhsBSSID
            ) == .orderedSame
        }

        return lhs.ssid == rhs.ssid
    }
}

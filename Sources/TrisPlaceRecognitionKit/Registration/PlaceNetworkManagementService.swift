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
        // Preserve the existing behavior:
        // do not request Wi-Fi for an unknown place.
        _ = try await findPlace(id: placeID)

        guard let current = await wifiProvider.currentNetwork(),
              !current.ssid.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
            throw PlaceNetworkManagementError.currentWiFiUnavailable
        }

        let bssid = current.bssid?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let identity = PlaceNetworkIdentity(
            ssid: current.ssid,
            bssid: bssid?.isEmpty == false ? bssid : nil
        )

        guard let updated = try await placeStore.update(
            id: placeID,
            { place in
                var networks = place.networkIdentities

                if networks.contains(where: {
                    PlaceNetworkMutation.isSameNetwork(
                        $0,
                        identity
                    )
                }) {
                    return place
                }

                networks.append(identity)

                return PlaceNetworkMutation.replacingNetworks(
                    in: place,
                    with: networks
                )
            }
        ) else {
            throw PlaceNetworkManagementError.placeNotFound(placeID)
        }

        return updated
    }

    public func removeNetwork(
        _ network: PlaceNetworkIdentity,
        from placeID: UUID
    ) async throws -> RegisteredPlace {
        guard let updated = try await placeStore.update(
            id: placeID,
            { place in
                var networks = place.networkIdentities

                guard let index = networks.firstIndex(where: {
                    PlaceNetworkMutation.isSameNetwork(
                        $0,
                        network
                    )
                }) else {
                    throw PlaceNetworkManagementError.networkNotRegistered
                }

                networks.remove(at: index)

                return PlaceNetworkMutation.replacingNetworks(
                    in: place,
                    with: networks
                )
            }
        ) else {
            throw PlaceNetworkManagementError.placeNotFound(placeID)
        }

        return updated
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

    private enum PlaceNetworkMutation {

        static func replacingNetworks(
            in place: RegisteredPlace,
            with networks: [PlaceNetworkIdentity]
        ) -> RegisteredPlace {
            let primary = networks.first
                ?? PlaceNetworkIdentity(
                    ssid: nil,
                    bssid: nil
                )

            return RegisteredPlace(
                id: place.id,
                name: place.name,
                location: place.location,
                networkIdentity: primary,
                additionalNetworkIdentities: Array(
                    networks.dropFirst()
                )
            )
        }

        static func isSameNetwork(
            _ lhs: PlaceNetworkIdentity,
            _ rhs: PlaceNetworkIdentity
        ) -> Bool {
            let lhsBSSID = lhs.bssid?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let rhsBSSID = rhs.bssid?
                .trimmingCharacters(in: .whitespacesAndNewlines)

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
}

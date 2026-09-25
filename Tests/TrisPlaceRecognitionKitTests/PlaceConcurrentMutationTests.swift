//
//  PlaceConcurrentMutationTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceConcurrentMutationTests {

    @Test
    func addingWiFiDoesNotOverwriteConcurrentNameChange() async throws {
        let store = InMemoryPlaceStore()

        let original = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_MAIN",
                bssid: "11:22:33:44:55:66"
            )
        )

        try await store.save(original)

        let wifiProvider = PausedWiFiProvider()

        let networkService = PlaceNetworkManagementService(
            placeStore: store,
            wifiProvider: wifiProvider
        )

        let managementService = PlaceManagementService(
            placeStore: store,
            locationProvider: MockLocationProvider()
        )

        // Begin adding Wi-Fi, but pause before the
        // current network request completes.
        let addNetworkTask = Task {
            try await networkService.addCurrentNetwork(
                to: original.id
            )
        }

        await wifiProvider.waitUntilRequested()

        // Rename the place while Wi-Fi registration
        // is waiting for its asynchronous result.
        _ = try await managementService.renamePlace(
            id: original.id,
            to: "회사헬스장"
        )

        // Finish the original Wi-Fi request.
        await wifiProvider.respond(
            with: WiFiNetwork(
                ssid: "GYM_SECOND",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        _ = try await addNetworkTask.value

        let places = try await store.fetchAll()

        let saved = try #require(
            places.first(where: {
                $0.id == original.id
            })
        )

        // Both changes must survive.
        #expect(saved.name.value == "회사헬스장")
        #expect(saved.networkIdentities.count == 2)
        #expect(
            saved.additionalNetworkIdentities.first?.ssid
                == "GYM_SECOND"
        )
    }
}

// A test provider that lets us control exactly when
// the asynchronous Wi-Fi request completes.
private actor PausedWiFiProvider: WiFiProviding {

    private var requestObserver:
        CheckedContinuation<Void, Never>?

    private var pendingRequest:
        CheckedContinuation<WiFiNetwork?, Never>?

    func currentNetwork() async -> WiFiNetwork? {
        await withCheckedContinuation { continuation in
            pendingRequest = continuation

            requestObserver?.resume()
            requestObserver = nil
        }
    }

    func waitUntilRequested() async {
        if pendingRequest != nil {
            return
        }

        await withCheckedContinuation { continuation in
            requestObserver = continuation
        }
    }

    func respond(
        with network: WiFiNetwork?
    ) {
        pendingRequest?.resume(
            returning: network
        )

        pendingRequest = nil
    }
}

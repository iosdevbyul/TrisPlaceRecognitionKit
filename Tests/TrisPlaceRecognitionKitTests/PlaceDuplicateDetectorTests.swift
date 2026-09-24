//
//  PlaceDuplicateDetectorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceDuplicateDetectorTests {

    @Test
    func detectsSameBSSIDAcrossAdditionalNetworks() throws {
        let existing = try makePlace(
            name: "헬스장",
            latitude: 37.0,
            networks: [
                .init(
                    ssid: "GYM_MAIN",
                    bssid: "11:22:33:44:55:66"
                ),
                .init(
                    ssid: "GYM_SECOND",
                    bssid: "AA:BB:CC:DD:EE:FF"
                )
            ]
        )

        let candidate = try makePlace(
            name: "새장소",
            latitude: 38.0,
            networks: [
                .init(
                    ssid: "OTHER_WIFI",
                    bssid: "aa:bb:cc:dd:ee:ff"
                )
            ]
        )

        let warnings = PlaceDuplicateDetector.warnings(
            for: candidate,
            among: [existing]
        )

        #expect(warnings.count == 1)
        #expect(warnings[0].reasons == [.sameBSSID])
    }

    @Test
    func detectsSameSSIDWithDifferentBSSID() throws {
        let existing = try makePlace(
            name: "헬스장",
            latitude: 37.0,
            networks: [
                .init(
                    ssid: "GYM_WIFI",
                    bssid: "11:22:33:44:55:66"
                )
            ]
        )

        let candidate = try makePlace(
            name: "새장소",
            latitude: 38.0,
            networks: [
                .init(
                    ssid: "GYM_WIFI",
                    bssid: "AA:BB:CC:DD:EE:FF"
                )
            ]
        )

        let warnings = PlaceDuplicateDetector.warnings(
            for: candidate,
            among: [existing]
        )

        #expect(warnings.count == 1)
        #expect(warnings[0].reasons == [.sameSSID])
    }

    @Test
    func detectsOverlappingGPSAreas() throws {
        let existing = try makePlace(
            name: "헬스장",
            latitude: 37.5665,
            radius: 100
        )

        let candidate = try makePlace(
            name: "회사",
            latitude: 37.5665,
            radius: 150
        )

        let warnings = PlaceDuplicateDetector.warnings(
            for: candidate,
            among: [existing]
        )

        #expect(warnings.count == 1)

        #expect(
            warnings[0].reasons == [
                .overlappingGPS(distanceMeters: 0)
            ]
        )
    }

    @Test
    func ignoresDistantPlaces() throws {
        let existing = try makePlace(
            name: "헬스장",
            latitude: 37.0
        )

        let candidate = try makePlace(
            name: "회사",
            latitude: 38.0
        )

        let warnings = PlaceDuplicateDetector.warnings(
            for: candidate,
            among: [existing]
        )

        #expect(warnings.isEmpty)
    }

    @Test
    func excludesSamePlaceWhenEditing() throws {
        let place = try makePlace(
            name: "헬스장",
            latitude: 37.5665
        )

        let warnings = PlaceDuplicateDetector.warnings(
            for: place,
            among: [place]
        )

        #expect(warnings.isEmpty)
    }
}

private extension PlaceDuplicateDetectorTests {

    func makePlace(
        name: String,
        latitude: Double,
        radius: Double = 100,
        networks: [PlaceNetworkIdentity] = []
    ) throws -> RegisteredPlace {
        RegisteredPlace(
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: latitude,
                longitude: 126.9780,
                recognitionRadius: radius
            ),
            networkIdentity: networks.first
                ?? PlaceNetworkIdentity(
                    ssid: nil,
                    bssid: nil
                ),
            additionalNetworkIdentities: Array(
                networks.dropFirst()
            )
        )
    }
}

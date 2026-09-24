//
//  RegisteredPlaceCodableTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct RegisteredPlaceCodableTests {

    @Test
    func encodesAndDecodesRegisteredPlaces() throws {
        let gym = RegisteredPlace(
            id: UUID(
                uuidString: "00000000-0000-0000-0000-000000000001"
            )!,
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let park = RegisteredPlace(
            id: UUID(
                uuidString: "00000000-0000-0000-0000-000000000002"
            )!,
            name: try PlaceName("공원"),
            location: PlaceLocation(
                latitude: 37.5,
                longitude: 127.0,
                recognitionRadius: 200
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )

        let original = [gym, park]

        let data = try JSONEncoder().encode(original)

        let decoded = try JSONDecoder().decode(
            [RegisteredPlace].self,
            from: data
        )

        #expect(decoded == original)
        #expect(decoded[0].name.value == "헬스장")
        #expect(decoded[1].networkIdentity.ssid == nil)
    }

    @Test
    func rejectsEmptyNameWhenDecoding() throws {
        let data = try JSONEncoder().encode("   ")

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                PlaceName.self,
                from: data
            )
        }
    }

    @Test
    func rejectsLongNameWhenDecoding() throws {
        let data = try JSONEncoder().encode(
            "가나다라마바사아자차카"
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                PlaceName.self,
                from: data
            )
        }
    }

    @Test
    func trimsWhitespaceWhenDecoding() throws {
        let data = try JSONEncoder().encode(
            "  헬스장  "
        )

        let decoded = try JSONDecoder().decode(
            PlaceName.self,
            from: data
        )

        #expect(decoded.value == "헬스장")
    }
    
    @Test
    func decodesLegacyPlaceWithoutAdditionalNetworks() throws {
        let legacyJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "헬스장",
            "location": {
                "latitude": 37.5665,
                "longitude": 126.978,
                "recognitionRadius": 100
            },
            "networkIdentity": {
                "ssid": "GYM_WIFI",
                "bssid": "AA:BB:CC:DD:EE:FF"
            }
        }
        """

        let place = try JSONDecoder().decode(
            RegisteredPlace.self,
            from: Data(legacyJSON.utf8)
        )

        #expect(place.additionalNetworkIdentities.isEmpty)
        #expect(place.networkIdentities.count == 1)
    }

    @Test
    func encodesAndDecodesMultipleNetworks() throws {
        let place = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            ),
            additionalNetworkIdentities: [
                PlaceNetworkIdentity(
                    ssid: "GYM_WIFI",
                    bssid: "11:22:33:44:55:66"
                ),
                PlaceNetworkIdentity(
                    ssid: "GYM_GUEST",
                    bssid: nil
                )
            ]
        )

        let data = try JSONEncoder().encode(place)

        let restored = try JSONDecoder().decode(
            RegisteredPlace.self,
            from: data
        )

        #expect(restored == place)
        #expect(restored.networkIdentities.count == 3)
    }
}

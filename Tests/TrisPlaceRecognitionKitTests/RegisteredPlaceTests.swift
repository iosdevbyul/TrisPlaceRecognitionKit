//
//  RegisteredPlaceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct RegisteredPlaceTests {

    @Test
    func initializesRegisteredPlace() throws {
        let id = UUID(
            uuidString: "00000000-0000-0000-0000-000000000001"
        )!

        let name = try PlaceName(
            "헬스장"
        )

        let location = PlaceLocation(
            latitude: 37.5665,
            longitude: 126.9780,
            recognitionRadius: 100
        )

        let networkIdentity = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let place = RegisteredPlace(
            id: id,
            name: name,
            location: location,
            networkIdentity: networkIdentity
        )

        #expect(place.id == id)
        #expect(place.name == name)
        #expect(place.location == location)

        #expect(
            place.networkIdentity == networkIdentity
        )
    }

    @Test
    func allowsPlaceWithoutWiFiInformation() throws {
        let place = RegisteredPlace(
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

        #expect(
            place.networkIdentity.ssid == nil
        )

        #expect(
            place.networkIdentity.bssid == nil
        )
    }

    @Test
    func createsUniqueIdentifierByDefault() throws {
        let location = PlaceLocation(
            latitude: 37.5,
            longitude: 127.0,
            recognitionRadius: 100
        )

        let networkIdentity = PlaceNetworkIdentity(
            ssid: nil,
            bssid: nil
        )

        let firstPlace = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: location,
            networkIdentity: networkIdentity
        )

        let secondPlace = RegisteredPlace(
            name: try PlaceName("헬스장"),
            location: location,
            networkIdentity: networkIdentity
        )

        #expect(
            firstPlace.id != secondPlace.id
        )
    }
}

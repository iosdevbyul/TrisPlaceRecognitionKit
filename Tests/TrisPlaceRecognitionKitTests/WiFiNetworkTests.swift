//
//  WiFiNetworkTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Testing

@testable import TrisPlaceRecognitionKit

struct WiFiNetworkTests {

    @Test
    func initializesWiFiNetwork() {
        let network = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        #expect(network.ssid == "GYM_WIFI")
        #expect(
            network.bssid == "AA:BB:CC:DD:EE:FF"
        )
    }

    @Test
    func allowsMissingBSSID() {
        let network = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: nil
        )

        #expect(network.ssid == "GYM_WIFI")
        #expect(network.bssid == nil)
    }
}

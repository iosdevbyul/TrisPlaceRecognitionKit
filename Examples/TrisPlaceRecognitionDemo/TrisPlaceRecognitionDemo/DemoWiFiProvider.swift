//
//  DemoWiFiProvider.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-09-27.
//


import TrisPlaceRecognitionKit

struct DemoWiFiProvider: WiFiProviding {

    func currentNetwork() async -> WiFiNetwork? {
        WiFiNetwork(
            ssid: "DEMO_WIFI",
            bssid: "02:11:22:33:44:55"
        )
    }
}

//
//  SystemWiFiProvider.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import NetworkExtension

public struct SystemWiFiProvider: WiFiProviding {

    public init() {}

    public func currentNetwork() async -> WiFiNetwork? {
        guard let network = await NEHotspotNetwork.fetchCurrent() else {
            return nil
        }

        return WiFiNetwork(
            ssid: network.ssid,
            bssid: network.bssid
        )
    }
}

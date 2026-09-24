//
//  PlaceWiFiMatcherTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceWiFiMatcherTests {

    @Test
    func matchesSameBSSID() {
        let registered = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let current = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: "aa:bb:cc:dd:ee:ff"
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .bssid)
    }

    @Test
    func prefersBSSIDWhenSSIDChanged() {
        let registered = PlaceNetworkIdentity(
            ssid: "OLD_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let current = WiFiNetwork(
            ssid: "NEW_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .bssid)
    }

    @Test
    func matchesSSIDWhenBSSIDChanged() {
        let registered = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let current = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: "11:22:33:44:55:66"
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .ssid)
    }

    @Test
    func matchesSSIDWithoutBSSID() {
        let registered = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: nil
        )

        let current = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: nil
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .ssid)
    }

    @Test
    func rejectsDifferentNetwork() {
        let registered = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let current = WiFiNetwork(
            ssid: "HOME_WIFI",
            bssid: "11:22:33:44:55:66"
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .mismatch)
    }

    @Test
    func treatsSSIDAsCaseSensitive() {
        let registered = PlaceNetworkIdentity(
            ssid: "Gym_WiFi",
            bssid: nil
        )

        let current = WiFiNetwork(
            ssid: "gym_wifi",
            bssid: nil
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .mismatch)
    }

    @Test
    func reportsUnavailableCurrentNetwork() {
        let registered = PlaceNetworkIdentity(
            ssid: "GYM_WIFI",
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: nil
        )

        #expect(result == .unavailable)
    }

    @Test
    func reportsUnavailableBSSID() {
        let registered = PlaceNetworkIdentity(
            ssid: nil,
            bssid: "AA:BB:CC:DD:EE:FF"
        )

        let current = WiFiNetwork(
            ssid: "GYM_WIFI",
            bssid: nil
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: current
        )

        #expect(result == .unavailable)
    }

    @Test
    func supportsPlacesWithoutWiFi() {
        let registered = PlaceNetworkIdentity(
            ssid: nil,
            bssid: nil
        )

        let result = PlaceWiFiMatcher.match(
            registered: registered,
            current: nil
        )

        #expect(result == .notConfigured)
    }
}

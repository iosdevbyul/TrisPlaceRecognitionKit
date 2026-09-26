//
//  PlaceWiFiMatcher.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation

enum PlaceWiFiMatch: Sendable, Equatable {
    case bssid
    case ssid
    case mismatch
    case unavailable
    case notConfigured
}

enum PlaceWiFiMatcher {

    static func match(
        registered: PlaceNetworkIdentity,
        current: WiFiNetwork?
    ) -> PlaceWiFiMatch {
        let registeredSSID = registered.ssid

        let registeredBSSID = registered.bssid?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let hasSSID = registeredSSID.map {
            !$0.isEmpty
        } ?? false

        let hasBSSID = registeredBSSID.map {
            !$0.isEmpty
        } ?? false

        guard hasSSID || hasBSSID else {
            return .notConfigured
        }

        guard let current else {
            return .unavailable
        }

        let currentBSSID = current.bssid?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if let registeredBSSID,
           !registeredBSSID.isEmpty,
           let currentBSSID,
           !currentBSSID.isEmpty,
           registeredBSSID.caseInsensitiveCompare(
               currentBSSID
           ) == .orderedSame {
            return .bssid
        }

        if let registeredSSID,
           !registeredSSID.isEmpty,
           registeredSSID == current.ssid {
            return .ssid
        }

        // BSSID is the only stored identity, but
        // the current BSSID could not be obtained.
        if !hasSSID,
           hasBSSID,
           currentBSSID == nil {
            return .unavailable
        }

        return .mismatch
    }
    
    static func match(
        registered: [PlaceNetworkIdentity],
        current: WiFiNetwork?
    ) -> PlaceWiFiMatch {
        var hasConfiguredNetwork = false
        var hasSSIDMatch = false
        var hasUnavailableNetwork = false

        for identity in registered {
            let result = match(
                registered: identity,
                current: current
            )

            switch result {
            case .bssid:
                return .bssid

            case .ssid:
                hasConfiguredNetwork = true
                hasSSIDMatch = true

            case .unavailable:
                hasConfiguredNetwork = true
                hasUnavailableNetwork = true

            case .mismatch:
                hasConfiguredNetwork = true

            case .notConfigured:
                continue
            }
        }

        if hasSSIDMatch {
            return .ssid
        }

        if hasUnavailableNetwork {
            return .unavailable
        }

        return hasConfiguredNetwork
            ? .mismatch
            : .notConfigured
    }
}

//
//  PlaceRecognitionService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import TrisLocationKit

@MainActor
public final class PlaceRecognitionService {

    private let locationProvider: any LocationProviding
    private let wifiProvider: any WiFiProviding
    private let placeStore: any PlaceStoring
    private let locationQualityPolicy: PlaceLocationQualityPolicy
    
    public init(
        locationProvider: any LocationProviding,
        wifiProvider: any WiFiProviding,
        placeStore: any PlaceStoring,
        locationQualityPolicy: PlaceLocationQualityPolicy = .init()
    ) {
        self.locationProvider = locationProvider
        self.wifiProvider = wifiProvider
        self.placeStore = placeStore
        self.locationQualityPolicy = locationQualityPolicy
    }

    // Preserve the existing GPS-constrained behavior.
    public func recognizeCurrentPlaces() async throws -> [RecognizedPlace] {
        let places = try await placeStore.fetchAll()

        guard !places.isEmpty else {
            return []
        }

        let currentLocation = try await locationProvider
            .requestCurrentLocation()

        guard PlaceLocationQualityValidator.isAcceptable(
            currentLocation,
            policy: locationQualityPolicy
        ) else {
            return []
        }

        let currentWiFi = await wifiProvider.currentNetwork()

        let recognizedPlaces = places.compactMap { place
            -> RecognizedPlace? in
            guard currentLocation.horizontalAccuracy
                    <= place.location.recognitionRadius else {
                return nil
            }
            guard let distance = PlaceProximityMatcher.distanceMeters(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude,
                from: place.location
            ),
            distance <= place.location.recognitionRadius else {
                return nil
            }

            let wiFiMatch = PlaceWiFiMatcher.match(
                registered: place.networkIdentities,
                current: currentWiFi
            )

            let evidence: PlaceRecognitionEvidence

            switch wiFiMatch {
            case .bssid:
                evidence = .bssid

            case .ssid:
                evidence = .ssid

            case .unavailable:
                evidence = .gpsOnlyWiFiUnavailable

            case .notConfigured:
                evidence = .gpsOnlyNoWiFiConfigured

            case .mismatch:
                return nil
            }

            return RecognizedPlace(
                place: place,
                distanceMeters: distance,
                evidence: evidence
            )
        }

        return sorted(recognizedPlaces)
    }

    // Let the consuming app choose its recognition policy.
    public func recognizeCurrentPlaces(
        policy: PlaceRecognitionPolicy
    ) async throws -> [RecognizedPlace] {
        switch policy {
        case .gpsConstrained:
            return try await recognizeCurrentPlaces()

        case .wifiFirst:
            return try await recognizeWiFiFirstPlaces()
        }
    }
}

private extension PlaceRecognitionService {

    func recognizeWiFiFirstPlaces() async throws -> [RecognizedPlace] {
        let places = try await placeStore.fetchAll()

        guard !places.isEmpty else {
            return []
        }

        // Only request Wi-Fi information if at least one
        // registered place has a Wi-Fi identity.
        let hasWiFiPlaces = places.contains { place in
            !place.networkIdentities.isEmpty
        }

        if hasWiFiPlaces {
            let currentWiFi = await wifiProvider.currentNetwork()

            let wifiMatches = places.compactMap { place
                -> RecognizedPlace? in

                let match = PlaceWiFiMatcher.match(
                    registered: place.networkIdentities,
                    current: currentWiFi
                )

                let evidence: PlaceRecognitionEvidence

                switch match {
                case .bssid:
                    evidence = .bssid

                case .ssid:
                    evidence = .ssid

                case .mismatch,
                     .unavailable,
                     .notConfigured:
                    return nil
                }

                return RecognizedPlace(
                    place: place,
                    distanceMeters: nil,
                    evidence: evidence
                )
            }

            // A Wi-Fi match is sufficient. Do not request GPS.
            if !wifiMatches.isEmpty {
                return sorted(wifiMatches)
            }
        }

        // GPS is only used for places registered without Wi-Fi.
        let gpsOnlyPlaces = places.filter { place in
            place.networkIdentities.isEmpty
        }

        guard !gpsOnlyPlaces.isEmpty else {
            return []
        }

        let currentLocation = try await locationProvider
            .requestCurrentLocation()

        guard PlaceLocationQualityValidator.isAcceptable(
            currentLocation,
            policy: locationQualityPolicy
        ) else {
            return []
        }

        let gpsMatches = gpsOnlyPlaces.compactMap { place
            -> RecognizedPlace? in
            guard currentLocation.horizontalAccuracy
                    <= place.location.recognitionRadius else {
                return nil
            }
            guard let distance = PlaceProximityMatcher.distanceMeters(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude,
                from: place.location
            ),
            distance <= place.location.recognitionRadius else {
                return nil
            }

            return RecognizedPlace(
                place: place,
                distanceMeters: distance,
                evidence: .gpsOnlyNoWiFiConfigured
            )
        }

        return sorted(gpsMatches)
    }

    func sorted(
        _ places: [RecognizedPlace]
    ) -> [RecognizedPlace] {
        places.sorted { lhs, rhs in
            if lhs.evidence.priority != rhs.evidence.priority {
                return lhs.evidence.priority > rhs.evidence.priority
            }

            let lhsDistance = lhs.distanceMeters ?? .infinity
            let rhsDistance = rhs.distanceMeters ?? .infinity

            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return lhs.place.id.uuidString
                < rhs.place.id.uuidString
        }
    }
}

private extension PlaceRecognitionEvidence {

    var priority: Int {
        switch self {
        case .bssid:
            return 3

        case .ssid:
            return 2

        case .gpsOnlyWiFiUnavailable,
             .gpsOnlyNoWiFiConfigured:
            return 1
        }
    }
}

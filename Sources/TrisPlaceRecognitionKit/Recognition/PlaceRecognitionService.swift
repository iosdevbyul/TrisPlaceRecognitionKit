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
            guard let location = place.location else {
                return nil
            }
            guard currentLocation.horizontalAccuracy
                    <= location.recognitionRadius else {
                return nil
            }
            guard let distance = PlaceProximityMatcher.distanceMeters(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude,
                from: location
            ),
            distance <= location.recognitionRadius else {
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
    
    var locationAuthorizationStatus:
        LocationAuthorizationStatus {

        locationProvider.authorizationStatus
    }

    func requestAlwaysLocationAuthorization() {

        locationProvider
            .requestAlwaysAuthorization()
    }

    func fetchRegisteredPlacesForBackgroundMonitoring()
        async throws -> [RegisteredPlace] {

        try await placeStore.fetchAll()
    }

    func currentWiFiEvidence(
        for place: RegisteredPlace
    ) async -> PlaceRecognitionEvidence? {
        let currentWiFi =
            await wifiProvider.currentNetwork()

        switch PlaceWiFiMatcher.match(
            registered: place.networkIdentities,
            current: currentWiFi
        ) {
        case .bssid:
            return .bssid

        case .ssid:
            return .ssid

        case .mismatch,
             .unavailable,
             .notConfigured:
            return nil
        }
    }

    func requestBackgroundMonitoringLocation()
        async throws -> LocationPoint? {

        let location =
            try await locationProvider
                .requestCurrentLocation()

        guard PlaceLocationQualityValidator
            .isAcceptable(
                location,
                policy: locationQualityPolicy
            )
        else {
            return nil
        }

        return location
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

        case .wifiOrGPS:
            return try await recognizeWiFiOrGPSPlaces()
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
                && place.location != nil
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
            guard let location = place.location else {
                return nil
            }
            guard currentLocation.horizontalAccuracy
                    <= location.recognitionRadius else {
                return nil
            }
            guard let distance = PlaceProximityMatcher.distanceMeters(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude,
                from: location
            ),
            distance <= location.recognitionRadius else {
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

    func recognizeWiFiOrGPSPlaces() async throws -> [RecognizedPlace] {
        var places = try await placeStore.fetchAll()

        guard !places.isEmpty else {
            return []
        }

        let currentWiFi = await wifiProvider.currentNetwork()

        let locationPoint =
            try? await locationProvider
                .requestCurrentLocation()

        let currentLocation =
            locationPoint.flatMap { point in
                PlaceLocationQualityValidator.isAcceptable(
                    point,
                    policy: locationQualityPolicy
                )
                ? point
                : nil
            }

        // Wi-Fi-only registrations are enriched silently
        // once the same Wi-Fi and an acceptable GPS fix
        // become available together.
        if let currentLocation {
            for index in places.indices where places[index].location == nil {
                let match = PlaceWiFiMatcher.match(
                    registered: places[index].networkIdentities,
                    current: currentWiFi
                )

                guard match == .bssid || match == .ssid else {
                    continue
                }

                let enriched =
                    RegisteredPlace(
                        id: places[index].id,
                        name: places[index].name,
                        location:
                            PlaceLocation(
                                latitude:
                                    currentLocation.latitude,
                                longitude:
                                    currentLocation.longitude,
                                recognitionRadius:
                                    PlaceRegistrationService
                                        .defaultRecognitionRadius
                            ),
                        networkIdentity:
                            places[index].networkIdentity,
                        additionalNetworkIdentities:
                            places[index]
                                .additionalNetworkIdentities
                    )

                try await placeStore.save(
                    enriched
                )

                places[index] = enriched
            }
        }

        let recognized = places.compactMap { place
            -> RecognizedPlace? in

            let wiFiMatch =
                PlaceWiFiMatcher.match(
                    registered:
                        place.networkIdentities,
                    current:
                        currentWiFi
                )

            let wiFiEvidence:
                PlaceRecognitionEvidence?

            switch wiFiMatch {
            case .bssid:
                wiFiEvidence = .bssid
            case .ssid:
                wiFiEvidence = .ssid
            case .mismatch,
                 .unavailable,
                 .notConfigured:
                wiFiEvidence = nil
            }

            var gpsDistance: Double?

            if let currentLocation,
               let location = place.location,
               currentLocation.horizontalAccuracy
                    <= location.recognitionRadius,
               let distance =
                    PlaceProximityMatcher.distanceMeters(
                        latitude:
                            currentLocation.latitude,
                        longitude:
                            currentLocation.longitude,
                        from:
                            location
                    ),
               distance <= location.recognitionRadius {

                gpsDistance = distance
            }

            if let wiFiEvidence {
                return RecognizedPlace(
                    place: place,
                    distanceMeters: gpsDistance,
                    evidence: wiFiEvidence
                )
            }

            if let gpsDistance {
                return RecognizedPlace(
                    place: place,
                    distanceMeters: gpsDistance,
                    evidence:
                        place.networkIdentities.isEmpty
                        ? .gpsOnlyNoWiFiConfigured
                        : .gpsOnlyWiFiUnavailable
                )
            }

            return nil
        }

        return sorted(
            recognized
        )
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

        case .systemRegion:
            return 0
        }
    }
}

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

    public init(
        locationProvider: any LocationProviding,
        wifiProvider: any WiFiProviding,
        placeStore: any PlaceStoring
    ) {
        self.locationProvider = locationProvider
        self.wifiProvider = wifiProvider
        self.placeStore = placeStore
    }

    public func recognizeCurrentPlaces() async throws -> [RecognizedPlace] {
        let places = try await placeStore.fetchAll()

        // 등록된 장소가 없다면 위치나 Wi-Fi를 요청하지 않는다.
        guard !places.isEmpty else {
            return []
        }

        let currentLocation = try await locationProvider
            .requestCurrentLocation()

        // 유효하지 않은 위치 정확도는 인식에 사용하지 않는다.
        guard currentLocation.horizontalAccuracy.isFinite,
              currentLocation.horizontalAccuracy >= 0 else {
            return []
        }

        let currentWiFi = await wifiProvider.currentNetwork()

        let recognizedPlaces = places.compactMap { place
            -> RecognizedPlace? in

            guard let distance = PlaceProximityMatcher.distanceMeters(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude,
                from: place.location
            ),
            distance <= place.location.recognitionRadius else {
                return nil
            }

            let wiFiMatch = PlaceWiFiMatcher.match(
                registered: place.networkIdentity,
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

        return recognizedPlaces.sorted { lhs, rhs in
            if lhs.evidence.priority != rhs.evidence.priority {
                return lhs.evidence.priority > rhs.evidence.priority
            }

            if lhs.distanceMeters != rhs.distanceMeters {
                return lhs.distanceMeters < rhs.distanceMeters
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

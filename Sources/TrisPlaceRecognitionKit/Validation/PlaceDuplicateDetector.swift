//
//  PlaceDuplicateDetector.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-25.
//


import Foundation

public enum PlaceDuplicateDetector {

    public static func warnings(
        for candidate: RegisteredPlace,
        among existingPlaces: [RegisteredPlace]
    ) -> [PlaceDuplicateWarning] {

        existingPlaces
            .filter { $0.id != candidate.id }
            .compactMap { existing -> PlaceDuplicateWarning? in
                var reasons: [PlaceDuplicateReason] = []

                if let wifiReason = wifiDuplicateReason(
                    candidate: candidate,
                    existing: existing
                ) {
                    reasons.append(wifiReason)
                }

                if let distance = overlappingDistance(
                    candidate: candidate,
                    existing: existing
                ) {
                    reasons.append(
                        .overlappingGPS(distanceMeters: distance)
                    )
                }

                guard !reasons.isEmpty else {
                    return nil
                }

                return PlaceDuplicateWarning(
                    existingPlace: existing,
                    reasons: reasons
                )
            }
            .sorted {
                $0.existingPlace.id.uuidString
                    < $1.existingPlace.id.uuidString
            }
    }
}

private extension PlaceDuplicateDetector {

    static func wifiDuplicateReason(
        candidate: RegisteredPlace,
        existing: RegisteredPlace
    ) -> PlaceDuplicateReason? {

        let candidateNetworks = candidate.networkIdentities
        let existingNetworks = existing.networkIdentities

        // Compare every registered access point.
        // BSSID matches take precedence over SSID matches.
        for candidateNetwork in candidateNetworks {
            for existingNetwork in existingNetworks {
                guard let lhs = nonEmptyBSSID(
                    candidateNetwork.bssid
                ),
                let rhs = nonEmptyBSSID(
                    existingNetwork.bssid
                ) else {
                    continue
                }

                if lhs.caseInsensitiveCompare(rhs) == .orderedSame {
                    return .sameBSSID
                }
            }
        }

        for candidateNetwork in candidateNetworks {
            for existingNetwork in existingNetworks {
                guard let lhs = nonEmptySSID(
                    candidateNetwork.ssid
                ),
                let rhs = nonEmptySSID(
                    existingNetwork.ssid
                ) else {
                    continue
                }

                if lhs == rhs {
                    return .sameSSID
                }
            }
        }

        return nil
    }

    static func overlappingDistance(
        candidate: RegisteredPlace,
        existing: RegisteredPlace
    ) -> Double? {

        let candidateRadius = candidate.location.recognitionRadius
        let existingRadius = existing.location.recognitionRadius

        guard candidateRadius.isFinite,
              candidateRadius > 0,
              existingRadius.isFinite,
              existingRadius > 0 else {
            return nil
        }

        guard let distance = PlaceProximityMatcher.distanceMeters(
            latitude: candidate.location.latitude,
            longitude: candidate.location.longitude,
            from: existing.location
        ) else {
            return nil
        }

        let combinedRadius = candidateRadius + existingRadius

        guard distance <= combinedRadius else {
            return nil
        }

        return distance
    }

    static func nonEmptyBSSID(
        _ value: String?
    ) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? nil : trimmed
    }

    static func nonEmptySSID(
        _ value: String?
    ) -> String? {
        guard let value,
              !value.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
            return nil
        }

        // SSID matching remains case-sensitive.
        return value
    }
}

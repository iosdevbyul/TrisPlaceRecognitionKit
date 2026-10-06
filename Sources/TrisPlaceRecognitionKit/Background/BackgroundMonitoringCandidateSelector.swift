//
//  BackgroundMonitoringCandidateSelector.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

enum BackgroundMonitoringCandidateSelector {

    static func select(
        from places: [RegisteredPlace],
        currentLatitude: Double,
        currentLongitude: Double,
        prioritizedPlaceIDs: Set<UUID> = [],
        policy: BackgroundRecognitionPolicy = .init()
    ) -> [BackgroundMonitoringCandidate] {

        let candidates = places.compactMap { place
            -> BackgroundMonitoringCandidate? in

            guard let location = place.location else {
                return nil
            }

            guard let distance =
                    PlaceProximityMatcher.distanceMeters(
                        latitude: currentLatitude,
                        longitude: currentLongitude,
                        from: location
                    ) else {
                return nil
            }

            return BackgroundMonitoringCandidate(
                place: place,
                distanceMeters: distance
            )
        }

        let sorted = candidates.sorted { lhs, rhs in

            let lhsIsPrioritized =
                prioritizedPlaceIDs.contains(
                    lhs.place.id
                )

            let rhsIsPrioritized =
                prioritizedPlaceIDs.contains(
                    rhs.place.id
                )

            if lhsIsPrioritized != rhsIsPrioritized {
                return lhsIsPrioritized
            }

            if lhs.distanceMeters != rhs.distanceMeters {
                return lhs.distanceMeters
                    < rhs.distanceMeters
            }

            return lhs.place.id.uuidString
                < rhs.place.id.uuidString
        }

        return Array(
            sorted.prefix(
                policy.maximumMonitoredPlaces
            )
        )
    }
}

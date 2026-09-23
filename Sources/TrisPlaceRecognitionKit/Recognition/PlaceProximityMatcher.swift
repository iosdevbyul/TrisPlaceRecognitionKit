//
//  PlaceProximityMatcher.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import CoreLocation
import Foundation

enum PlaceProximityMatcher {

    static func distanceMeters(
        latitude: Double,
        longitude: Double,
        from place: PlaceLocation
    ) -> Double? {
        guard isValidCoordinate(
            latitude: latitude,
            longitude: longitude
        ),
        isValidCoordinate(
            latitude: place.latitude,
            longitude: place.longitude
        ),
        place.recognitionRadius.isFinite,
        place.recognitionRadius > 0 else {
            return nil
        }

        let currentLocation = CLLocation(
            latitude: latitude,
            longitude: longitude
        )

        let registeredLocation = CLLocation(
            latitude: place.latitude,
            longitude: place.longitude
        )

        return currentLocation.distance(
            from: registeredLocation
        )
    }

    static func isWithinRadius(
        latitude: Double,
        longitude: Double,
        of place: PlaceLocation
    ) -> Bool {
        guard let distance = distanceMeters(
            latitude: latitude,
            longitude: longitude,
            from: place
        ) else {
            return false
        }

        return distance <= place.recognitionRadius
    }

    private static func isValidCoordinate(
        latitude: Double,
        longitude: Double
    ) -> Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }
}

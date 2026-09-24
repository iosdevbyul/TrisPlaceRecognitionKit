//
//  PlaceProximityMatcherTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceProximityMatcherTests {

    private let seoulCityHall = PlaceLocation(
        latitude: 37.5665,
        longitude: 126.9780,
        recognitionRadius: 100
    )

    @Test
    func matchesSameLocation() {
        let result = PlaceProximityMatcher.isWithinRadius(
            latitude: 37.5665,
            longitude: 126.9780,
            of: seoulCityHall
        )

        #expect(result)
    }

    @Test
    func matchesNearbyLocation() {
        let result = PlaceProximityMatcher.isWithinRadius(
            latitude: 37.5666,
            longitude: 126.9780,
            of: seoulCityHall
        )

        #expect(result)
    }

    @Test
    func rejectsLocationOutsideRadius() {
        let result = PlaceProximityMatcher.isWithinRadius(
            latitude: 37.5685,
            longitude: 126.9780,
            of: seoulCityHall
        )

        #expect(!result)
    }

    @Test
    func rejectsInvalidRecognitionRadius() {
        let place = PlaceLocation(
            latitude: 37.5665,
            longitude: 126.9780,
            recognitionRadius: -10
        )

        let result = PlaceProximityMatcher.isWithinRadius(
            latitude: 37.5665,
            longitude: 126.9780,
            of: place
        )

        #expect(!result)
    }

    @Test
    func rejectsInvalidCoordinates() {
        let result = PlaceProximityMatcher.isWithinRadius(
            latitude: 100,
            longitude: 126.9780,
            of: seoulCityHall
        )

        #expect(!result)
    }
}

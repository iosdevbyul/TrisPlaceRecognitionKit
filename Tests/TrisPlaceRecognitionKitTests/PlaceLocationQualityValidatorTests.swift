//
//  PlaceLocationQualityValidatorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

struct PlaceLocationQualityValidatorTests {

    private let now = Date(
        timeIntervalSince1970: 1_000_000
    )

    @Test
    func acceptsRecentAccurateLocation() {
        let location = makeLocation(
            accuracy: 5,
            timestamp: now
        )

        let result = PlaceLocationQualityValidator.isAcceptable(
            location,
            policy: .init(),
            now: now
        )

        #expect(result)
    }

    @Test
    func rejectsInaccurateLocation() {
        let location = makeLocation(
            accuracy: 250,
            timestamp: now
        )

        let result = PlaceLocationQualityValidator.isAcceptable(
            location,
            policy: .init(),
            now: now
        )

        #expect(!result)
    }

    @Test
    func rejectsStaleLocation() {
        let location = makeLocation(
            accuracy: 5,
            timestamp: now.addingTimeInterval(-120)
        )

        let result = PlaceLocationQualityValidator.isAcceptable(
            location,
            policy: .init(),
            now: now
        )

        #expect(!result)
    }

    @Test
    func rejectsTimestampTooFarInFuture() {
        let location = makeLocation(
            accuracy: 5,
            timestamp: now.addingTimeInterval(60)
        )

        let result = PlaceLocationQualityValidator.isAcceptable(
            location,
            policy: .init(),
            now: now
        )

        #expect(!result)
    }

    @Test
    func acceptsCustomQualityPolicy() {
        let location = makeLocation(
            accuracy: 150,
            timestamp: now.addingTimeInterval(-60)
        )

        let policy = PlaceLocationQualityPolicy(
            maximumHorizontalAccuracy: 200,
            maximumAge: 120
        )

        let result = PlaceLocationQualityValidator.isAcceptable(
            location,
            policy: policy,
            now: now
        )

        #expect(result)
    }
}

private extension PlaceLocationQualityValidatorTests {

    func makeLocation(
        accuracy: Double,
        timestamp: Date
    ) -> LocationPoint {
        LocationPoint(
            latitude: 37.5665,
            longitude: 126.9780,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: timestamp
        )
    }
}

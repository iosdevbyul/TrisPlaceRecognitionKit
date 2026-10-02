//
//  BackgroundRecognitionPolicyTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Testing

@testable import TrisPlaceRecognitionKit

struct BackgroundRecognitionPolicyTests {

    @Test
    func usesTwentyPlacesByDefault() {

        let policy = BackgroundRecognitionPolicy()

        #expect(
            policy.maximumMonitoredPlaces == 20
        )
    }

    @Test
    func acceptsSmallerMonitoringLimit() {

        let policy = BackgroundRecognitionPolicy(
            maximumMonitoredPlaces: 10
        )

        #expect(
            policy.maximumMonitoredPlaces == 10
        )
    }

    @Test
    func rejectsMonitoringLimitAboveSystemMaximum() {

        let policy = BackgroundRecognitionPolicy(
            maximumMonitoredPlaces: 21
        )

        #expect(
            policy.maximumMonitoredPlaces
                == BackgroundRecognitionPolicy
                    .systemMaximumMonitoredPlaces
        )
    }

    @Test
    func rejectsNonPositiveMonitoringLimit() {

        let zero = BackgroundRecognitionPolicy(
            maximumMonitoredPlaces: 0
        )

        let negative = BackgroundRecognitionPolicy(
            maximumMonitoredPlaces: -1
        )

        #expect(
            zero.maximumMonitoredPlaces == 20
        )

        #expect(
            negative.maximumMonitoredPlaces == 20
        )
    }
}

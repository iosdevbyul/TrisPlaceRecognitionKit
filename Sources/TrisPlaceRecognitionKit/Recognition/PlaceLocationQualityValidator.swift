//
//  PlaceLocationQualityValidator.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//

import Foundation
import TrisLocationKit

enum PlaceLocationQualityValidator {

    static func isAcceptable(
        _ location: LocationPoint,
        policy: PlaceLocationQualityPolicy,
        now: Date = Date()
    ) -> Bool {
        guard policy.maximumHorizontalAccuracy.isFinite,
              policy.maximumHorizontalAccuracy > 0,
              policy.maximumAge.isFinite,
              policy.maximumAge > 0,
              policy.futureTolerance.isFinite,
              policy.futureTolerance >= 0 else {
            return false
        }

        let accuracy = location.horizontalAccuracy

        guard accuracy.isFinite,
              accuracy >= 0,
              accuracy <= policy.maximumHorizontalAccuracy else {
            return false
        }

        let age = now.timeIntervalSince(
            location.timestamp
        )

        return age >= -policy.futureTolerance
            && age <= policy.maximumAge
    }
}

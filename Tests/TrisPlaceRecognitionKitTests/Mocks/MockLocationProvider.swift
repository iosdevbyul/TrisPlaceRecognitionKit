//
//  MockLocationProvider.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Foundation
import TrisLocationKit

@MainActor
final class MockLocationProvider: LocationProviding {

    var authorizationStatus:
        LocationAuthorizationStatus =
        .authorizedWhenInUse

    var locationPoint: LocationPoint?

    var requestCurrentLocationError:
        Error?

    private(set)
    var requestCurrentLocationCallCount = 0

    private(set)
    var requestAlwaysAuthorizationCallCount = 0

    private(set)
    var locationUpdatesCallCount = 0

    private(set)
    var stopLocationUpdatesCallCount = 0

    func requestWhenInUseAuthorization()
        async -> LocationAuthorizationStatus {

        authorizationStatus
    }

    func requestAlwaysAuthorization() {

        requestAlwaysAuthorizationCallCount += 1
    }

    func requestCurrentLocation()
        async throws -> LocationPoint {

        requestCurrentLocationCallCount += 1

        if let requestCurrentLocationError {
            throw requestCurrentLocationError
        }

        guard let locationPoint else {
            throw LocationError
                .locationUnavailable
        }

        return locationPoint
    }

    func locationUpdates()
        -> AsyncThrowingStream<
            LocationPoint,
            Error
        > {

        locationUpdatesCallCount += 1

        return AsyncThrowingStream {
            continuation in

            continuation.finish()
        }
    }

    func stopLocationUpdates() {

        stopLocationUpdatesCallCount += 1
    }
}

//
//  BackgroundRegionMonitoringServiceTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct BackgroundRegionMonitoringServiceTests {

    @Test
    func synchronizesCandidatesAsRegions()
        async throws {

        let monitor =
            SpyBackgroundRegionMonitor()

        let service =
            BackgroundRegionMonitoringService(
                monitor: monitor
            )

        let gym = try makeCandidate(
            name: "Gym",
            latitude: 37.5665,
            distanceMeters: 10
        )

        let office = try makeCandidate(
            name: "Office",
            latitude: 37.5700,
            distanceMeters: 200
        )

        try await service.synchronize(
            candidates: [
                gym,
                office
            ],
            requiresCandidateRefresh: false
        )

        #expect(
            monitor
                .synchronizedRegionBatches
                .count == 1
        )

        let regions =
            try #require(
                monitor
                    .synchronizedRegionBatches
                    .first
            )

        #expect(regions.count == 2)

        #expect(
            regions[0].placeID
                == gym.place.id
        )

        #expect(
            regions[0].latitude
                == gym.place.location.latitude
        )

        #expect(
            regions[0].longitude
                == gym.place.location.longitude
        )

        #expect(
            regions[0].radius
                == gym.place.location
                    .recognitionRadius
        )

        #expect(
            regions[1].placeID
                == office.place.id
        )

        #expect(
            monitor.stopAllCallCount == 0
        )
    }

    @Test
    func emptyCandidatesStopAllMonitoring()
        async throws {

        let monitor =
            SpyBackgroundRegionMonitor()

        let service =
            BackgroundRegionMonitoringService(
                monitor: monitor
            )

            try await service.synchronize(
                candidates: [],
                requiresCandidateRefresh: false
            )

        #expect(
            monitor
                .synchronizedRegionBatches
                .isEmpty
        )

        #expect(
            monitor.stopAllCallCount == 1
        )
    }

    @Test
    func stopStopsAllMonitoring() async {

        let monitor =
            SpyBackgroundRegionMonitor()

        let service =
            BackgroundRegionMonitoringService(
                monitor: monitor
            )

        await service.stop()

        #expect(
            monitor.stopAllCallCount == 1
        )
    }
}

private extension
    BackgroundRegionMonitoringServiceTests {

    func makeCandidate(
        name: String,
        latitude: Double,
        distanceMeters: Double
    ) throws -> BackgroundMonitoringCandidate {

        let place = RegisteredPlace(
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: latitude,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity:
                PlaceNetworkIdentity(
                    ssid: nil,
                    bssid: nil
                )
        )

        return BackgroundMonitoringCandidate(
            place: place,
            distanceMeters:
                distanceMeters
        )
    }
    
    @Test
    func enablesCandidateRefreshWhenRequired()
        async throws {

        let monitor =
            SpyBackgroundRegionMonitor()

        let service =
            BackgroundRegionMonitoringService(
                monitor: monitor
            )

        let gym =
            try makeCandidate(
                name: "Gym",
                latitude: 37.5665,
                distanceMeters: 10
            )

        try await service.synchronize(
            candidates: [
                gym
            ],
            requiresCandidateRefresh: true
        )

        #expect(
            monitor
                .candidateRefreshMonitoringValues
                == [
                    true
                ]
        )
    }
}

@MainActor
private final class SpyBackgroundRegionMonitor:
    BackgroundRegionMonitoring {

    private(set)
    var synchronizedRegionBatches:
        [[BackgroundMonitoredRegion]] = []

    private(set)
    var stopAllCallCount = 0
    
    private(set)
    var candidateRefreshMonitoringValues:
        [Bool] = []
    
    func setCandidateRefreshMonitoringEnabled(
        _ enabled: Bool
    ) async throws {

        candidateRefreshMonitoringValues
            .append(
                enabled
            )
    }

    func events()
        -> AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        > {

        AsyncThrowingStream {
            continuation in

            continuation.finish()
        }
    }

    func synchronize(
        regions:
            [BackgroundMonitoredRegion]
    ) async throws {

        synchronizedRegionBatches.append(
            regions
        )
    }

    func stopAll() async {
        stopAllCallCount += 1
    }
}

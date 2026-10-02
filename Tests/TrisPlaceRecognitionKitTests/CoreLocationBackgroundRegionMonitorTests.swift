//
//  CoreLocationBackgroundRegionMonitorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import CoreLocation
import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

@MainActor
struct CoreLocationBackgroundRegionMonitorTests {

    @Test
    func synchronizeStartsRequestedRegion()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let placeID = UUID()

        let region = try makeRegion(
            placeID: placeID,
            latitude: 37.5665,
            radius: 100
        )

        try await monitor.synchronize(
            regions: [
                region
            ]
        )

        #expect(
            client.startedRegions.count == 1
        )

        let started =
            try #require(
                client.startedRegions.first
                    as? CLCircularRegion
            )

        #expect(
            started.identifier
                == CoreLocationBackgroundRegionMonitor
                    .regionIdentifier(
                        for: placeID
                    )
        )

        #expect(
            started.center.latitude
                == 37.5665
        )

        #expect(
            started.center.longitude
                == 126.9780
        )

        #expect(
            started.radius == 100
        )

        #expect(started.notifyOnEntry)
        #expect(started.notifyOnExit)
    }

    @Test
    func synchronizeKeepsUnchangedRegionAndRemovesOnlyStaleOwnedRegion()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let keepID = UUID()
        let staleID = UUID()

        let keep =
            makeSystemRegion(
                placeID: keepID,
                latitude: 37.5665,
                radius: 100
            )

        let stale =
            makeSystemRegion(
                placeID: staleID,
                latitude: 37.5700,
                radius: 100
            )

        let foreign =
            makeForeignRegion(
                identifier:
                    "WorkoutLocationKit.region"
            )

        client.monitoredRegions = [
            keep,
            stale,
            foreign
        ]

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let desired =
            try makeRegion(
                placeID: keepID,
                latitude: 37.5665,
                radius: 100
            )

        try await monitor.synchronize(
            regions: [
                desired
            ]
        )

        #expect(
            client.startedRegions.isEmpty
        )

        #expect(
            client
                .stoppedRegions
                .map(\.identifier)
                == [
                    stale.identifier
                ]
        )

        #expect(
            !client
                .stoppedRegions
                .contains {
                    $0.identifier
                        == foreign.identifier
                }
        )
    }

    @Test
    func synchronizeReplacesChangedOwnedRegion()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let placeID = UUID()

        client.monitoredRegions = [
            makeSystemRegion(
                placeID: placeID,
                latitude: 37.5665,
                radius: 50
            )
        ]

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let desired =
            try makeRegion(
                placeID: placeID,
                latitude: 37.5665,
                radius: 100
            )

        try await monitor.synchronize(
            regions: [
                desired
            ]
        )

        #expect(
            client.startedRegions.count == 1
        )

        let replacement =
            try #require(
                client.startedRegions.first
                    as? CLCircularRegion
            )

        #expect(
            replacement.radius == 100
        )

        #expect(
            client.stoppedRegions.isEmpty
        )
    }

    @Test
    func stopAllStopsOnlyOwnedRegions()
        async {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let first =
            makeSystemRegion(
                placeID: UUID(),
                latitude: 37.5665,
                radius: 100
            )

        let second =
            makeSystemRegion(
                placeID: UUID(),
                latitude: 37.5700,
                radius: 100
            )

        let foreign =
            makeForeignRegion(
                identifier:
                    "WorkoutLocationKit.region"
            )

        client.monitoredRegions = [
            first,
            second,
            foreign
        ]

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        await monitor.stopAll()

        let stoppedIdentifiers =
            Set(
                client
                    .stoppedRegions
                    .map(\.identifier)
            )

        #expect(
            stoppedIdentifiers == [
                first.identifier,
                second.identifier
            ]
        )

        #expect(
            !stoppedIdentifiers.contains(
                foreign.identifier
            )
        )
    }

    @Test
    func emitsEnterAndExitTriggers()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let placeID = UUID()

        let region =
            makeSystemRegion(
                placeID: placeID,
                latitude: 37.5665,
                radius: 100
            )

        let stream = monitor.events()

        var iterator =
            stream.makeAsyncIterator()

        client.simulateEnter(
            region
        )

        let enter =
            try await iterator.next()

        #expect(
            enter
                == .monitoredRegionEntered(
                    placeID: placeID
                )
        )

        client.simulateExit(
            region
        )

        let exit =
            try await iterator.next()

        #expect(
            exit
                == .monitoredRegionExited(
                    placeID: placeID
                )
        )
    }

    @Test
    func rejectsUnavailableMonitoring()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        client
            .isCircularRegionMonitoringAvailable =
            false

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let region =
            try makeRegion(
                placeID: UUID(),
                latitude: 37.5665,
                radius: 100
            )

        let error =
            await captureMonitoringError {

                try await monitor.synchronize(
                    regions: [
                        region
                    ]
                )
            }

        #expect(
            error == .monitoringUnavailable
        )

        #expect(
            client.startedRegions.isEmpty
        )
    }

    @Test
    func rejectsRadiusBeyondSystemMaximum()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        client.maximumRegionMonitoringDistance =
            500

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let placeID = UUID()

        let region =
            try makeRegion(
                placeID: placeID,
                latitude: 37.5665,
                radius: 600
            )

        let error =
            await captureMonitoringError {

                try await monitor.synchronize(
                    regions: [
                        region
                    ]
                )
            }

        #expect(
            error
                == .radiusExceedsMaximum(
                    placeID: placeID,
                    maximum: 500
                )
        )

        #expect(
            client.startedRegions.isEmpty
        )
    }

    @Test
    func protectsCapacityUsedByOtherLibraries()
        async throws {

        let client =
            MockCoreLocationRegionMonitoringClient()

        client.monitoredRegions =
            (0..<19).map { index in

                makeForeignRegion(
                    identifier:
                        "OtherLibrary.\(index)"
                )
            }

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let first =
            try makeRegion(
                placeID: UUID(),
                latitude: 37.5665,
                radius: 100
            )

        let second =
            try makeRegion(
                placeID: UUID(),
                latitude: 37.5700,
                radius: 100
            )

        let error =
            await captureMonitoringError {

                try await monitor.synchronize(
                    regions: [
                        first,
                        second
                    ]
                )
            }

        #expect(
            error
                == .insufficientSystemCapacity(
                    requested: 2,
                    available: 1
                )
        )

        #expect(
            client.startedRegions.isEmpty
        )

        #expect(
            client.stoppedRegions.isEmpty
        )
    }

    @Test
    func monitoringFailureEndsEventStreamWithError()
        async {

        let client =
            MockCoreLocationRegionMonitoringClient()

        let monitor =
            CoreLocationBackgroundRegionMonitor(
                client: client
            )

        let placeID = UUID()

        let region =
            makeSystemRegion(
                placeID: placeID,
                latitude: 37.5665,
                radius: 100
            )

        let stream = monitor.events()

        var iterator =
            stream.makeAsyncIterator()

        client.simulateFailure(
            region
        )

        var receivedError:
            BackgroundRegionMonitoringError?

        do {
            _ = try await iterator.next()

            receivedError = nil
        } catch let error
            as BackgroundRegionMonitoringError {

            receivedError = error
        } catch {
            receivedError = nil
        }

        #expect(
            receivedError
                == .systemMonitoringFailed(
                    placeID: placeID
                )
        )
    }
}

private extension
    CoreLocationBackgroundRegionMonitorTests {

    func makeRegion(
        placeID: UUID,
        latitude: Double,
        radius: Double
    ) throws -> BackgroundMonitoredRegion {

        let place =
            RegisteredPlace(
                id: placeID,
                name:
                    try PlaceName(
                        "Gym"
                    ),
                location:
                    PlaceLocation(
                        latitude: latitude,
                        longitude: 126.9780,
                        recognitionRadius:
                            radius
                    ),
                networkIdentity:
                    PlaceNetworkIdentity(
                        ssid: nil,
                        bssid: nil
                    )
            )

        let candidate =
            BackgroundMonitoringCandidate(
                place: place,
                distanceMeters: 0
            )

        return BackgroundMonitoredRegion(
            candidate: candidate
        )
    }

    func makeSystemRegion(
        placeID: UUID,
        latitude: Double,
        radius: Double
    ) -> CLCircularRegion {

        let region =
            CLCircularRegion(
                center:
                    CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: 126.9780
                    ),
                radius: radius,
                identifier:
                    CoreLocationBackgroundRegionMonitor
                        .regionIdentifier(
                            for: placeID
                        )
            )

        region.notifyOnEntry = true
        region.notifyOnExit = true

        return region
    }

    func makeForeignRegion(
        identifier: String
    ) -> CLCircularRegion {

        CLCircularRegion(
            center:
                CLLocationCoordinate2D(
                    latitude: 37.5665,
                    longitude: 126.9780
                ),
            radius: 100,
            identifier: identifier
        )
    }

    func captureMonitoringError(
        _ operation:
            () async throws -> Void
    ) async
        -> BackgroundRegionMonitoringError? {

        do {
            try await operation()

            return nil
        } catch let error
            as BackgroundRegionMonitoringError {

            return error
        } catch {
            return nil
        }
    }
}

@MainActor
private final class
    MockCoreLocationRegionMonitoringClient:
    CoreLocationRegionMonitoringClient {

    var monitoredRegions:
        [CLRegion] = []

    var maximumRegionMonitoringDistance:
        CLLocationDistance = 1_000

    var isCircularRegionMonitoringAvailable =
        true

    var onRegionEntered:
        ((CLRegion) -> Void)?

    var onRegionExited:
        ((CLRegion) -> Void)?

    var onMonitoringFailure:
        ((CLRegion?, any Error) -> Void)?

    private(set)
    var startedRegions:
        [CLRegion] = []

    private(set)
    var stoppedRegions:
        [CLRegion] = []

    func startMonitoring(
        for region: CLRegion
    ) {
        startedRegions.append(
            region
        )

        monitoredRegions.removeAll {
            $0.identifier
                == region.identifier
        }

        monitoredRegions.append(
            region
        )
    }

    func stopMonitoring(
        for region: CLRegion
    ) {
        stoppedRegions.append(
            region
        )

        monitoredRegions.removeAll {
            $0.identifier
                == region.identifier
        }
    }

    func simulateEnter(
        _ region: CLRegion
    ) {
        onRegionEntered?(
            region
        )
    }

    func simulateExit(
        _ region: CLRegion
    ) {
        onRegionExited?(
            region
        )
    }

    func simulateFailure(
        _ region: CLRegion?
    ) {
        onMonitoringFailure?(
            region,
            MockMonitoringFailure()
        )
    }
}

private struct MockMonitoringFailure:
    Error {}

//
//  PlaceVisitManagerBackgroundTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceVisitManagerBackgroundTests {

    @Test
    func startsBackgroundRecognitionWithSingleLocationSnapshot()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            latitude: 37.5665,
            ssid: nil
        )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    .init(),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        #expect(
            manager
                .isBackgroundRecognitionEnabled
        )

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .count == 1
        )

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .first?
                .first?
                .placeID == gym.id
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 1
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        #expect(
            locationProvider
                .stopLocationUpdatesCallCount
                == 0
        )

        #expect(
            locationProvider
                .requestAlwaysAuthorizationCallCount
                == 0
        )

        await manager
            .stopBackgroundRecognition()
    }

    @Test
    func requestsAlwaysAuthorizationBeforeBackgroundMonitoring()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        locationProvider.authorizationStatus =
            .authorizedWhenInUse

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            latitude: 37.5665,
            ssid: nil
        )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    .init(),
                backgroundMonitor:
                    backgroundMonitor
            )

        var receivedError:
            BackgroundRecognitionManagerError?

        do {

            try await manager
                .startBackgroundRecognition()

            Issue.record(
                "Expected Always authorization requirement."
            )

        } catch let error
            as BackgroundRecognitionManagerError {

            receivedError = error

        } catch {

            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(
            receivedError
                == .alwaysAuthorizationRequired
        )

        #expect(
            locationProvider
                .requestAlwaysAuthorizationCallCount
                == 1
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 0
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .isEmpty
        )

        #expect(
            !manager
                .isBackgroundRecognitionEnabled
        )
    }

    @Test
    func noRegisteredPlacesDoesNotRequestLocationOrAuthorization()
        async throws {

        let locationProvider =
            MockLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    .init(),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        #expect(
            manager
                .isBackgroundRecognitionEnabled
        )

        #expect(
            backgroundMonitor
                .stopAllCallCount == 1
        )

        #expect(
            locationProvider
                .requestAlwaysAuthorizationCallCount
                == 0
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 0
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        await manager
            .stopBackgroundRecognition()
    }

    @Test
    func backgroundEnterEventUpdatesActiveVisit()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider(
                network: WiFiNetwork(
                    ssid: "GYM_WIFI",
                    bssid: nil
                )
            )

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            latitude: 37.5665,
            ssid: "GYM_WIFI"
        )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .wifiFirst,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    .init(),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        backgroundMonitor.emit(
            .monitoredRegionEntered(
                placeID: gym.id
            )
        )

        await waitUntil {
            manager.activeVisits.count == 1
        }

        #expect(
            manager.activeVisits
                .first?
                .placeID == gym.id
        )

        // One location request was needed only to
        // calculate background monitoring candidates.
        //
        // Wi-Fi confirmed the arrival, so no second
        // GPS request was required.
        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 1
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        let events =
            try await visitStore.fetchEvents()

        #expect(
            events.count == 1
        )

        #expect(
            events.first?.kind
                == .arrived
        )

        await manager
            .stopBackgroundRecognition()
    }

    @Test
    func stopBackgroundRecognitionDoesNotStartOrStopContinuousTracking()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym = try makePlace(
            name: "Gym",
            latitude: 37.5665,
            ssid: nil
        )

        try await placeStore.save(
            gym
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    .init(),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        await manager
            .stopBackgroundRecognition()

        #expect(
            !manager
                .isBackgroundRecognitionEnabled
        )

        #expect(
            backgroundMonitor
                .stopAllCallCount == 1
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        #expect(
            locationProvider
                .stopLocationUpdatesCallCount
                == 0
        )
    }
    
    @Test
    func disablesCandidateRefreshWhenAllPlacesFit()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let gym =
            try makePlace(
                name: "Gym",
                latitude: 37.5665,
                ssid: nil
            )

        let office =
            try makePlace(
                name: "Office",
                latitude: 37.5700,
                ssid: nil
            )

        try await placeStore.save(
            gym
        )

        try await placeStore.save(
            office
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    BackgroundRecognitionPolicy(
                        maximumMonitoredPlaces: 2
                    ),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .count == 1
        )

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .first?
                .count == 2
        )

        #expect(
            backgroundMonitor
                .candidateRefreshMonitoringValues
                == [
                    false
                ]
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 1
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        await manager
            .stopBackgroundRecognition()
    }
    
    @Test
    func enablesCandidateRefreshWhenPlacesExceedLimit()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let first =
            try makePlace(
                name: "First",
                latitude: 37.5665,
                ssid: nil
            )

        let second =
            try makePlace(
                name: "Second",
                latitude: 37.5670,
                ssid: nil
            )

        let third =
            try makePlace(
                name: "Third",
                latitude: 37.6000,
                ssid: nil
            )

        try await placeStore.save(
            first
        )

        try await placeStore.save(
            second
        )

        try await placeStore.save(
            third
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    BackgroundRecognitionPolicy(
                        maximumMonitoredPlaces: 2
                    ),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .first?
                .count == 2
        )

        #expect(
            backgroundMonitor
                .candidateRefreshMonitoringValues
                == [
                    true
                ]
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 1
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        await manager
            .stopBackgroundRecognition()
    }
    
    @Test
    func significantLocationChangeReselectsNearbyCandidates()
        async throws {

        let locationProvider =
            makeAuthorizedLocationProvider()

        let wifiProvider =
            MockWiFiProvider()

        let placeStore =
            MockPlaceStore()

        let visitStore =
            InMemoryPlaceVisitStore()

        let first =
            try makePlace(
                name: "First",
                latitude: 37.5665,
                ssid: nil
            )

        let second =
            try makePlace(
                name: "Second",
                latitude: 37.5670,
                ssid: nil
            )

        let third =
            try makePlace(
                name: "Third",
                latitude: 37.6000,
                ssid: nil
            )

        try await placeStore.save(
            first
        )

        try await placeStore.save(
            second
        )

        try await placeStore.save(
            third
        )

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let backgroundMonitor =
            TestBackgroundRegionMonitor()

        let manager =
            PlaceVisitManager(
                recognitionService:
                    recognitionService,
                visitStore:
                    visitStore,
                recognitionPolicy:
                    .gpsConstrained,
                visitPolicy:
                    .init(),
                refreshInterval:
                    15,
                backgroundRecognitionPolicy:
                    BackgroundRecognitionPolicy(
                        maximumMonitoredPlaces: 2
                    ),
                backgroundMonitor:
                    backgroundMonitor
            )

        try await manager
            .startBackgroundRecognition()

        let initialBatch =
            try #require(
                backgroundMonitor
                    .synchronizedRegionBatches
                    .first
            )

        let initialIDs =
            Set(
                initialBatch.map(
                    \.placeID
                )
            )

        #expect(
            initialIDs.contains(
                first.id
            )
        )

        #expect(
            initialIDs.contains(
                second.id
            )
        )

        #expect(
            !initialIDs.contains(
                third.id
            )
        )

        // Simulate the user moving far enough that the
        // significant-change service wakes the app.
        locationProvider.locationPoint =
            LocationPoint(
                latitude: 37.6000,
                longitude: 126.9780,
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                speed: 0,
                course: 0,
                timestamp: Date()
            )

        backgroundMonitor.emit(
            .significantLocationChange
        )

        await waitUntil {

            backgroundMonitor
                .synchronizedRegionBatches
                .count == 2
        }

        #expect(
            backgroundMonitor
                .synchronizedRegionBatches
                .count == 2
        )

        let refreshedBatch =
            try #require(
                backgroundMonitor
                    .synchronizedRegionBatches
                    .last
            )

        let refreshedIDs =
            Set(
                refreshedBatch.map(
                    \.placeID
                )
            )

        #expect(
            refreshedIDs.contains(
                third.id
            )
        )

        #expect(
            !refreshedIDs.contains(
                first.id
            )
        )

        #expect(
            locationProvider
                .requestCurrentLocationCallCount
                == 2
        )

        #expect(
            locationProvider
                .locationUpdatesCallCount
                == 0
        )

        #expect(
            locationProvider
                .stopLocationUpdatesCallCount
                == 0
        )

        // Candidate reselection is not visit evidence.
        #expect(
            manager.activeVisits.isEmpty
        )

        let events =
            try await visitStore.fetchEvents()

        #expect(
            events.isEmpty
        )

        await manager
            .stopBackgroundRecognition()
    }
}

private extension
    PlaceVisitManagerBackgroundTests {

    func makeAuthorizedLocationProvider()
        -> MockLocationProvider {

        let provider =
            MockLocationProvider()

        provider.authorizationStatus =
            .authorizedAlways

        provider.locationPoint =
            LocationPoint(
                latitude: 37.5665,
                longitude: 126.9780,
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                speed: 0,
                course: 0,
                timestamp: Date()
            )

        return provider
    }

    func makePlace(
        name: String,
        latitude: Double,
        ssid: String?
    ) throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName(
                name
            ),
            location:
                PlaceLocation(
                    latitude: latitude,
                    longitude: 126.9780,
                    recognitionRadius: 100
                ),
            networkIdentity:
                PlaceNetworkIdentity(
                    ssid: ssid,
                    bssid: nil
                )
        )
    }

    func waitUntil(
        _ condition:
            @MainActor () -> Bool
    ) async {

        for _ in 0..<100 {

            if condition() {
                return
            }

            try? await Task.sleep(
                nanoseconds: 1_000_000
            )
        }
    }
}

@MainActor
private final class TestBackgroundRegionMonitor:
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

    private var eventContinuation:
        AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        >.Continuation?

    func events()
        -> AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        > {

        AsyncThrowingStream {
            continuation in

            eventContinuation =
                continuation
        }
    }

    func synchronize(
        regions:
            [BackgroundMonitoredRegion]
    ) async throws {

        synchronizedRegionBatches
            .append(
                regions
            )
    }

    func stopAll() async {

        stopAllCallCount += 1
    }

    func emit(
        _ trigger:
            BackgroundRecognitionTrigger
    ) {

        eventContinuation?
            .yield(
                trigger
            )
    }
}

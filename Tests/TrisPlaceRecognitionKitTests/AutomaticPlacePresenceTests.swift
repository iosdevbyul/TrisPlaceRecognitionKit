import Foundation
import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct AutomaticPlacePresenceTests {

    @Test
    func registerLocationStoresGPSAndWiFi() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.locationPoint = locationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: "AA:BB:CC:DD:EE:FF"
            )
        )

        let store = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let place = try await service.registerLocation(
            name: "Gym"
        )

        #expect(place.location != nil)
        #expect(place.networkIdentity.ssid == "GYM_WIFI")
        #expect(await store.savedPlaceCount() == 1)
    }

    @Test
    func registerLocationStoresWiFiWhenGPSIsUnavailable() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.requestCurrentLocationError =
            LocationError.locationUnavailable

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let store = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let place = try await service.registerLocation(
            name: "Gym"
        )

        #expect(place.location == nil)
        #expect(place.networkIdentity.ssid == "GYM_WIFI")
        #expect(await store.savedPlaceCount() == 1)
    }

    @Test
    func registerLocationStoresGPSWhenWiFiIsUnavailable() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.locationPoint = locationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider()
        let store = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let place = try await service.registerLocation(
            name: "Gym"
        )

        #expect(place.location != nil)
        #expect(place.networkIdentities.isEmpty)
    }

    @Test
    func registerLocationFailsWhenNoSignalIsAvailable() async {
        let locationProvider = MockLocationProvider()
        locationProvider.requestCurrentLocationError =
            LocationError.locationUnavailable

        let wifiProvider = MockWiFiProvider()
        let store = MockPlaceStore()

        let service = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        do {
            _ = try await service.registerLocation(
                name: "Gym"
            )

            Issue.record(
                "Expected noAvailableSignal"
            )
        } catch let error as PlaceRegistrationError {
            #expect(error == .noAvailableSignal)
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        #expect(await store.savedPlaceCount() == 0)
    }

    @Test
    func wifiOrGPSRecognizesPlaceFromWiFiWhenGPSFails() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.requestCurrentLocationError =
            LocationError.locationUnavailable

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let store = MockPlaceStore()

        let place = RegisteredPlace(
            name: try PlaceName("Gym"),
            location: nil,
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        try await store.save(place)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let recognized =
            try await service.recognizeCurrentPlaces(
                policy: .wifiOrGPS
            )

        #expect(recognized.map(\.place.id) == [place.id])
        #expect(recognized.first?.evidence == .ssid)
    }

    @Test
    func wifiOrGPSRecognizesPlaceFromGPSWhenWiFiMismatches() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.locationPoint = locationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "OTHER_WIFI",
                bssid: nil
            )
        )

        let store = MockPlaceStore()

        let place = RegisteredPlace(
            name: try PlaceName("Gym"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        try await store.save(place)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        let recognized =
            try await service.recognizeCurrentPlaces(
                policy: .wifiOrGPS
            )

        #expect(recognized.map(\.place.id) == [place.id])
    }

    @Test
    func wifiOnlyPlaceIsSilentlyEnrichedWhenGPSBecomesAvailable() async throws {
        let locationProvider = MockLocationProvider()
        locationProvider.locationPoint = locationPoint(
            latitude: 37.5665,
            longitude: 126.9780
        )

        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        let store = MockPlaceStore()

        let place = RegisteredPlace(
            name: try PlaceName("Gym"),
            location: nil,
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        try await store.save(place)

        let service = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: store
        )

        _ = try await service.recognizeCurrentPlaces(
            policy: .wifiOrGPS
        )

        let restored = try await store.fetchAll()

        #expect(restored.first?.location != nil)
        #expect(
            restored.first?.location?.latitude
                == 37.5665
        )
        #expect(
            restored.first?.networkIdentity.ssid
                == "GYM_WIFI"
        )
    }

    @Test
    func dualSignalRegionExitKeepsVisitWhileWiFiStillMatches() async throws {
        let locationProvider = MockLocationProvider()
        let wifiProvider = MockWiFiProvider(
            network: WiFiNetwork(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )
        let placeStore = MockPlaceStore()
        let visitStore = InMemoryPlaceVisitStore()

        let place = RegisteredPlace(
            name: try PlaceName("Gym"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        try await placeStore.save(place)

        let record = PlaceVisitRecord(
            placeID: place.id,
            startedAt: Date(timeIntervalSince1970: 1_000),
            arrivalEvidence: .ssid
        )

        try await visitStore.apply(
            PlaceVisitUpdate(
                events: [
                    PlaceVisitEvent(
                        visitID: record.id,
                        placeID: place.id,
                        kind: .arrived,
                        occurredAt: record.startedAt
                    )
                ],
                startedVisits: [record]
            )
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let coordinator = PlaceVisitCoordinator(
            store: visitStore
        )

        _ = try await coordinator.restore()

        let processor = BackgroundRecognitionEventProcessor(
            recognitionService: recognitionService,
            coordinator: coordinator,
            recognitionPolicy: .wifiOrGPS
        )

        let result = try await processor.handle(
            .monitoredRegionExited(
                placeID: place.id
            ),
            at: Date(timeIntervalSince1970: 2_000)
        )

        #expect(result.events.isEmpty)
        #expect(
            try await coordinator
                .activeVisits()
                .first?
                .placeID == place.id
        )
    }

    @Test
    func dualSignalRegionExitEndsVisitAfterWiFiIsLost() async throws {
        let locationProvider = MockLocationProvider()
        let wifiProvider = MockWiFiProvider(
            network: nil
        )
        let placeStore = MockPlaceStore()
        let visitStore = InMemoryPlaceVisitStore()

        let place = RegisteredPlace(
            name: try PlaceName("Gym"),
            location: PlaceLocation(
                latitude: 37.5665,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: "GYM_WIFI",
                bssid: nil
            )
        )

        try await placeStore.save(place)

        let record = PlaceVisitRecord(
            placeID: place.id,
            startedAt: Date(timeIntervalSince1970: 1_000),
            arrivalEvidence: .ssid
        )

        try await visitStore.apply(
            PlaceVisitUpdate(
                events: [
                    PlaceVisitEvent(
                        visitID: record.id,
                        placeID: place.id,
                        kind: .arrived,
                        occurredAt: record.startedAt
                    )
                ],
                startedVisits: [record]
            )
        )

        let recognitionService = PlaceRecognitionService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        let coordinator = PlaceVisitCoordinator(
            store: visitStore
        )

        _ = try await coordinator.restore()

        let processor = BackgroundRecognitionEventProcessor(
            recognitionService: recognitionService,
            coordinator: coordinator,
            recognitionPolicy: .wifiOrGPS
        )

        let result = try await processor.handle(
            .monitoredRegionExited(
                placeID: place.id
            ),
            at: Date(timeIntervalSince1970: 2_000)
        )

        #expect(result.events.map(\.kind) == [.departed])
        #expect(
            try await coordinator
                .activeVisits()
                .isEmpty
        )
    }

    private func locationPoint(
        latitude: Double,
        longitude: Double
    ) -> LocationPoint {
        LocationPoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            speed: 0,
            course: 0,
            timestamp: Date()
        )
    }
}

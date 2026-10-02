//
//  BackgroundMonitoringCandidateSelectorTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
import Testing

@testable import TrisPlaceRecognitionKit

struct BackgroundMonitoringCandidateSelectorTests {

    @Test
    func selectsNearestPlacesFirst() throws {

        let near = try makePlace(
            name: "Near",
            latitude: 37.5665
        )

        let middle = try makePlace(
            name: "Middle",
            latitude: 37.5680
        )

        let far = try makePlace(
            name: "Far",
            latitude: 37.5700
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    far,
                    middle,
                    near
                ],
                currentLatitude: 37.5665,
                currentLongitude: 126.9780
            )

        #expect(result.count == 3)

        #expect(
            result.map(\.place.id) == [
                near.id,
                middle.id,
                far.id
            ]
        )
    }

    @Test
    func limitsCandidatesToTwentyByDefault() throws {

        let places = try (0..<25).map { index in

            try makePlace(
                name: "Place \(index)",
                latitude:
                    37.5665
                    + Double(index) * 0.001
            )
        }

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: places,
                currentLatitude: 37.5665,
                currentLongitude: 126.9780
            )

        #expect(result.count == 20)
    }

    @Test
    func respectsCustomCandidateLimit() throws {

        let places = try (0..<10).map { index in

            try makePlace(
                name: "Place \(index)",
                latitude:
                    37.5665
                    + Double(index) * 0.001
            )
        }

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: places,
                currentLatitude: 37.5665,
                currentLongitude: 126.9780,
                policy: BackgroundRecognitionPolicy(
                    maximumMonitoredPlaces: 3
                )
            )

        #expect(result.count == 3)

        #expect(
            result.map(\.place.id)
                == Array(
                    places.prefix(3)
                        .map(\.id)
                )
        )
    }

    @Test
    func prioritizesActiveVisitPlace() throws {

        let near = try makePlace(
            name: "Near",
            latitude: 37.5665
        )

        let middle = try makePlace(
            name: "Middle",
            latitude: 37.5675
        )

        let activeButFar = try makePlace(
            name: "Active",
            latitude: 37.6000
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    near,
                    middle,
                    activeButFar
                ],
                currentLatitude: 37.5665,
                currentLongitude: 126.9780,
                prioritizedPlaceIDs: [
                    activeButFar.id
                ],
                policy: BackgroundRecognitionPolicy(
                    maximumMonitoredPlaces: 2
                )
            )

        #expect(result.count == 2)

        #expect(
            result[0].place.id
                == activeButFar.id
        )

        #expect(
            result[1].place.id
                == near.id
        )
    }

    @Test
    func sortsPrioritizedPlacesByDistance() throws {

        let nearerActive = try makePlace(
            name: "NearGym",
            latitude: 37.5680
        )

        let fartherActive = try makePlace(
            name: "FarGym",
            latitude: 37.5800
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    fartherActive,
                    nearerActive
                ],
                currentLatitude: 37.5665,
                currentLongitude: 126.9780,
                prioritizedPlaceIDs: [
                    nearerActive.id,
                    fartherActive.id
                ]
            )

        #expect(
            result.map(\.place.id) == [
                nearerActive.id,
                fartherActive.id
            ]
        )
    }

    @Test
    func rejectsInvalidCurrentCoordinate() throws {

        let gym = try makePlace(
            name: "Gym",
            latitude: 37.5665
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    gym
                ],
                currentLatitude: 100,
                currentLongitude: 126.9780
            )

        #expect(result.isEmpty)
    }

    @Test
    func excludesPlaceWithInvalidCoordinate() throws {

        let valid = try makePlace(
            name: "Valid",
            latitude: 37.5665
        )

        let invalid = try makePlace(
            name: "Invalid",
            latitude: 100
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    invalid,
                    valid
                ],
                currentLatitude: 37.5665,
                currentLongitude: 126.9780
            )

        #expect(result.count == 1)

        #expect(
            result.first?.place.id
                == valid.id
        )
    }

    @Test
    func excludesPlaceWithInvalidRecognitionRadius() throws {

        let valid = try makePlace(
            name: "Valid",
            latitude: 37.5665
        )

        let invalid = RegisteredPlace(
            name: try PlaceName("Invalid"),
            location: PlaceLocation(
                latitude: 37.5670,
                longitude: 126.9780,
                recognitionRadius: -1
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )

        let result =
            BackgroundMonitoringCandidateSelector.select(
                from: [
                    invalid,
                    valid
                ],
                currentLatitude: 37.5665,
                currentLongitude: 126.9780
            )

        #expect(result.count == 1)

        #expect(
            result.first?.place.id
                == valid.id
        )
    }
}

private extension
    BackgroundMonitoringCandidateSelectorTests {

    func makePlace(
        name: String,
        latitude: Double
    ) throws -> RegisteredPlace {

        RegisteredPlace(
            name: try PlaceName(name),
            location: PlaceLocation(
                latitude: latitude,
                longitude: 126.9780,
                recognitionRadius: 100
            ),
            networkIdentity: PlaceNetworkIdentity(
                ssid: nil,
                bssid: nil
            )
        )
    }
}

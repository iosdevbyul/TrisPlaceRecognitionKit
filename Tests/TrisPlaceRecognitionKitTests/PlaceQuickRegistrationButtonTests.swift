//
//  PlaceQuickRegistrationButtonTests.swift
//  TrisPlaceRecognitionKitTests
//
//  Created by COMATOKI on 2026-10-06.
//

import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceQuickRegistrationButtonTests {

    @Test
    func createsButtonWithRegistrationService() {
        let service =
            PlaceRegistrationService(
                locationProvider:
                    MockLocationProvider(),
                wifiProvider:
                    MockWiFiProvider(),
                placeStore:
                    MockPlaceStore()
            )

        _ = PlaceQuickRegistrationButton(
            name:
                "Gym",
            registrationService:
                service
        )
    }

    @Test
    func createsButtonFromDependencies() {
        _ = PlaceQuickRegistrationButton(
            name:
                "Gym",
            placeStore:
                MockPlaceStore(),
            locationProvider:
                MockLocationProvider(),
            wifiProvider:
                MockWiFiProvider()
        )
    }
}

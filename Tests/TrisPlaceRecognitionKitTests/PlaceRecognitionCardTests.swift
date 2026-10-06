//
//  PlaceRecognitionCardTests.swift
//  TrisPlaceRecognitionKitTests
//
//  Created by COMATOKI on 2026-10-07.
//

import Testing
import TrisLocationKit

@testable import TrisPlaceRecognitionKit

@MainActor
struct PlaceRecognitionCardTests {

    @Test
    func createsCardWithAppOwnedRecognitionActions() {
        _ = PlaceRecognitionCard(
            configuration:
                PlaceRecognitionCardConfiguration(
                    title:
                        "헬스장 자동 감지",
                    registrationPrompt:
                        "현재 장소를 운동 장소로 등록하시겠습니까?",
                    registrationButtonTitle:
                        "운동 장소로 등록"
                ),
            placeStore:
                MockPlaceStore(),
            locationProvider:
                MockLocationProvider(),
            wifiProvider:
                MockWiFiProvider(),
            visitManager:
                nil,
            isRecognitionRequested:
                false,
            onEnableRecognition: {},
            onDisableRecognition: {}
        )
    }

    @Test
    func createsCardWithoutPlaceStoreWhilePreparing() {
        _ = PlaceRecognitionCard(
            placeStore:
                nil,
            locationProvider:
                MockLocationProvider(),
            wifiProvider:
                MockWiFiProvider(),
            visitManager:
                nil,
            isPreparing:
                true,
            isRecognitionRequested:
                false,
            onEnableRecognition: {},
            onDisableRecognition: {}
        )
    }
}

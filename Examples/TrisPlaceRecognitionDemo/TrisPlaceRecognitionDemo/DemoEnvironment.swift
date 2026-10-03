//
//  DemoEnvironment.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-09-27.
//

import Combine
import Foundation
import TrisLocationKit
import TrisPlaceRecognitionKit

@MainActor
final class DemoEnvironment:
    ObservableObject {

    @Published
    private(set)
    var store:
        (any PlaceStoring)?

    @Published
    private(set)
    var visitManager:
        PlaceVisitManager?

    @Published
    private(set)
    var isPreparing = false

    @Published
    private(set)
    var errorMessage: String?

    @Published
    private(set)
    var statusMessage: String?

    @Published
    private(set)
    var wasLaunchedForLocationEvent =
        false

    let locationProvider =
        CoreLocationProvider()

    #if targetEnvironment(simulator)

    let wifiProvider:
        any WiFiProviding =
            DemoWiFiProvider()

    #else

    let wifiProvider:
        any WiFiProviding =
            SystemWiFiProvider()

    #endif

    private static let
        backgroundRecognitionPreferenceKey =
            "TrisPlaceRecognitionDemo.backgroundRecognitionEnabled"

    var wantsBackgroundRecognition:
        Bool {

        UserDefaults.standard
            .bool(
                forKey:
                    Self
                        .backgroundRecognitionPreferenceKey
            )
    }

    var authorizationStatus:
        LocationAuthorizationStatus {

        locationProvider
            .authorizationStatus
    }

    // MARK: - App Launch

    func handleApplicationLaunch(
        wasLaunchedForLocationEvent: Bool
    ) async {

        self
            .wasLaunchedForLocationEvent =
            wasLaunchedForLocationEvent

        guard
            wantsBackgroundRecognition
        else {
            return
        }

        do {

            try await prepareServices()

            guard
                locationProvider
                    .authorizationStatus
                    == .authorizedAlways
            else {

                statusMessage =
                    "Background recognition is enabled, but Always location authorization is not available."

                return
            }

            try await visitManager?
                .startBackgroundRecognition()

            statusMessage =
                wasLaunchedForLocationEvent
                ? "Background recognition resumed after a location launch."
                : "Background recognition resumed."

            errorMessage =
                nil

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Demo Start

    func start() async {

        guard
            !isPreparing
        else {
            return
        }

        isPreparing =
            true

        errorMessage =
            nil

        defer {

            isPreparing =
                false
        }

        let authorization =
            await locationProvider
                .requestWhenInUseAuthorization()

        switch authorization {

        case .authorizedWhenInUse,
             .authorizedAlways:

            break

        case .notDetermined:

            errorMessage =
                "위치 권한 선택이 완료되지 않았습니다."

            return

        case .restricted:

            errorMessage =
                "위치 접근이 제한되어 있습니다."

            return

        case .denied:

            errorMessage =
                "위치 접근 권한이 필요합니다."

            return

        case .unknown:

            errorMessage =
                "위치 권한 상태를 확인할 수 없습니다."

            return
        }

        do {

            try await prepareServices()

            statusMessage =
                "Demo services are ready."

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Background Recognition

    func enableBackgroundRecognition()
        async {

        do {

            try await prepareServices()

            UserDefaults.standard
                .set(
                    true,
                    forKey:
                        Self
                            .backgroundRecognitionPreferenceKey
                )

            try await visitManager?
                .startBackgroundRecognition()

            statusMessage =
                "Background recognition is active."

            errorMessage =
                nil

        } catch let error
            as BackgroundRecognitionManagerError {

            handleBackgroundRecognitionError(
                error
            )

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    func disableBackgroundRecognition()
        async {

        UserDefaults.standard
            .set(
                false,
                forKey:
                    Self
                        .backgroundRecognitionPreferenceKey
            )

        await visitManager?
            .stopBackgroundRecognition()

        statusMessage =
            "Background recognition is disabled."

        errorMessage =
            nil
    }

    func retryBackgroundRecognition()
        async {

        guard
            wantsBackgroundRecognition
        else {
            return
        }

        await enableBackgroundRecognition()
    }

    // MARK: - Preparation

    private func prepareServices()
        async throws {

        if store != nil,
           visitManager != nil {

            return
        }

        let placeStore =
            try await PlaceStoreFactory
                .makeDefaultStore()

        let recognitionService =
            PlaceRecognitionService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        let manager =
            try PlaceVisitManager(
                recognitionService:
                    recognitionService,
                recognitionPolicy:
                    .wifiFirst
            )

        store =
            placeStore

        visitManager =
            manager
    }

    private func
        handleBackgroundRecognitionError(
            _ error:
                BackgroundRecognitionManagerError
        ) {

        switch error {

        case .alwaysAuthorizationRequired:

            statusMessage =
                "Always location authorization was requested. Approve it, then retry background recognition."

            errorMessage =
                nil

        case .authorizationDenied:

            errorMessage =
                "Location authorization is denied."

        case .authorizationRestricted:

            errorMessage =
                "Location authorization is restricted."

        case .authorizationUnknown:

            errorMessage =
                "The current location authorization state is unknown."

        case .unacceptableLocationSnapshot:

            errorMessage =
                "A usable location snapshot could not be obtained."
        }
    }
}

//
//  PlaceQuickRegistrationButton.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-06.
//

import SwiftUI
import TrisLocationKit

@MainActor
public struct PlaceQuickRegistrationButton: View {

    @State
    private var isRegistering = false

    private let name: String
    private let title: String

    private let registrationService:
        PlaceRegistrationService

    private let visitManager:
        PlaceVisitManager?

    private let onRegistered:
        @MainActor (RegisteredPlace) -> Void

    private let onError:
        @MainActor (Error) -> Void

    public init(
        name: String = "Place",
        title: String = "현재 장소 등록",
        registrationService:
            PlaceRegistrationService,
        visitManager:
            PlaceVisitManager? = nil,
        onRegistered:
            @escaping @MainActor (RegisteredPlace) -> Void = { _ in },
        onError:
            @escaping @MainActor (Error) -> Void = { _ in }
    ) {
        self.name = name
        self.title = title
        self.registrationService =
            registrationService
        self.visitManager =
            visitManager
        self.onRegistered =
            onRegistered
        self.onError =
            onError
    }

    public init(
        name: String = "Place",
        title: String = "현재 장소 등록",
        placeStore:
            any PlaceStoring,
        locationProvider:
            any LocationProviding,
        wifiProvider:
            any WiFiProviding =
                SystemWiFiProvider(),
        visitManager:
            PlaceVisitManager? = nil,
        onRegistered:
            @escaping @MainActor (RegisteredPlace) -> Void = { _ in },
        onError:
            @escaping @MainActor (Error) -> Void = { _ in }
    ) {
        self.init(
            name:
                name,
            title:
                title,
            registrationService:
                PlaceRegistrationService(
                    locationProvider:
                        locationProvider,
                    wifiProvider:
                        wifiProvider,
                    placeStore:
                        placeStore
                ),
            visitManager:
                visitManager,
            onRegistered:
                onRegistered,
            onError:
                onError
        )
    }

    public var body: some View {
        Button {
            guard !isRegistering else {
                return
            }

            Task {
                await registerCurrentPlace()
            }
        } label: {
            HStack(spacing: 8) {
                if isRegistering {
                    ProgressView()
                }

                Text(
                    isRegistering
                    ? "장소 등록 중"
                    : title
                )
            }
        }
        .disabled(isRegistering)
    }
}

private extension PlaceQuickRegistrationButton {

    func registerCurrentPlace() async {
        guard !isRegistering else {
            return
        }

        isRegistering = true

        defer {
            isRegistering = false
        }

        do {
            let place =
                try await registrationService
                    .registerLocation(
                        name:
                            name
                    )

            if let visitManager {
                try? await visitManager
                    .refreshBackgroundRecognition()

                try? await visitManager
                    .refresh()
            }

            onRegistered(
                place
            )
        } catch {
            onError(
                error
            )
        }
    }
}

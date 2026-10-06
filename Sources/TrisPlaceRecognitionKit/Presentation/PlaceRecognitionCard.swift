//
//  PlaceRecognitionCard.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-07.
//

import SwiftUI
import TrisLocationKit

public struct PlaceRecognitionCardConfiguration {
    public var title: String
    public var registrationPrompt: String
    public var registrationButtonTitle: String
    public var registrationNavigationTitle: String
    public var enableButtonTitle: String
    public var disableButtonTitle: String
    public var manageButtonTitle: String
    public var preparingMessage: String
    public var unavailableMessage: String
    public var unregisteredMessage: String

    public init(
        title: String = "장소 자동 인식",
        registrationPrompt: String = "현재 장소를 등록하시겠습니까?",
        registrationButtonTitle: String = "현재 장소 등록",
        registrationNavigationTitle: String = "장소 등록",
        enableButtonTitle: String = "자동 인식 켜기",
        disableButtonTitle: String = "자동 인식 끄기",
        manageButtonTitle: String = "장소 관리",
        preparingMessage: String = "장소 인식 준비 중",
        unavailableMessage: String = "장소 인식 서비스를 준비하고 있습니다.",
        unregisteredMessage: String = "현재 등록된 장소에 있지 않습니다."
    ) {
        self.title = title
        self.registrationPrompt = registrationPrompt
        self.registrationButtonTitle = registrationButtonTitle
        self.registrationNavigationTitle = registrationNavigationTitle
        self.enableButtonTitle = enableButtonTitle
        self.disableButtonTitle = disableButtonTitle
        self.manageButtonTitle = manageButtonTitle
        self.preparingMessage = preparingMessage
        self.unavailableMessage = unavailableMessage
        self.unregisteredMessage = unregisteredMessage
    }
}

@MainActor
public struct PlaceRecognitionCard: View {
    @State
    private var isShowingRegistration = false

    private let configuration:
        PlaceRecognitionCardConfiguration

    private let placeStore:
        (any PlaceStoring)?

    private let locationProvider:
        any LocationProviding

    private let wifiProvider:
        any WiFiProviding

    private let visitManager:
        PlaceVisitManager?

    private let isPreparing:
        Bool

    private let isRecognitionRequested:
        Bool

    private let statusMessage:
        String?

    private let errorMessage:
        String?

    private let onEnableRecognition:
        @MainActor () async -> Void

    private let onDisableRecognition:
        @MainActor () async -> Void

    private let onManagePlaces:
        (@MainActor () -> Void)?

    private let onRegistered:
        @MainActor (RegisteredPlace) -> Void

    public init(
        configuration:
            PlaceRecognitionCardConfiguration = .init(),
        placeStore:
            (any PlaceStoring)?,
        locationProvider:
            any LocationProviding,
        wifiProvider:
            any WiFiProviding = SystemWiFiProvider(),
        visitManager:
            PlaceVisitManager?,
        isPreparing:
            Bool = false,
        isRecognitionRequested:
            Bool,
        statusMessage:
            String? = nil,
        errorMessage:
            String? = nil,
        onEnableRecognition:
            @escaping @MainActor () async -> Void,
        onDisableRecognition:
            @escaping @MainActor () async -> Void,
        onManagePlaces:
            (@MainActor () -> Void)? = nil,
        onRegistered:
            @escaping @MainActor (RegisteredPlace) -> Void = { _ in }
    ) {
        self.configuration =
            configuration

        self.placeStore =
            placeStore

        self.locationProvider =
            locationProvider

        self.wifiProvider =
            wifiProvider

        self.visitManager =
            visitManager

        self.isPreparing =
            isPreparing

        self.isRecognitionRequested =
            isRecognitionRequested

        self.statusMessage =
            statusMessage

        self.errorMessage =
            errorMessage

        self.onEnableRecognition =
            onEnableRecognition

        self.onDisableRecognition =
            onDisableRecognition

        self.onManagePlaces =
            onManagePlaces

        self.onRegistered =
            onRegistered
    }

    public var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Label(
                configuration.title,
                systemImage: "location.fill"
            )
            .font(.headline)

            recognitionStatus

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            registrationPrompt

            controls
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .sheet(
            isPresented:
                $isShowingRegistration
        ) {
            registrationSheet
        }
    }
}

private extension PlaceRecognitionCard {
    @ViewBuilder
    var recognitionStatus:
        some View {

        if let visitManager {
            PlaceRecognitionCardStatusView(
                visitManager:
                    visitManager,
                unregisteredMessage:
                    configuration
                        .unregisteredMessage
            )
        } else if isPreparing {
            ProgressView(
                configuration.preparingMessage
            )
        } else {
            Text(
                configuration.unavailableMessage
            )
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var registrationPrompt:
        some View {

        if canOfferRegistration {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Text(
                    configuration
                        .registrationPrompt
                )
                .font(.subheadline)
                .fontWeight(.semibold)

                Button(
                    configuration
                        .registrationButtonTitle
                ) {
                    isShowingRegistration =
                        true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    var canOfferRegistration:
        Bool {

        guard
            placeStore != nil,
            let visitManager
        else {
            return false
        }

        return visitManager
            .recognizedPlaces
            .isEmpty
            && visitManager
                .activeVisits
                .isEmpty
    }

    var controls:
        some View {

        HStack {
            if isRecognitionRequested {
                Button(
                    configuration
                        .disableButtonTitle
                ) {
                    Task {
                        await onDisableRecognition()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button(
                    configuration
                        .enableButtonTitle
                ) {
                    Task {
                        await onEnableRecognition()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let onManagePlaces {
                Spacer()

                Button(
                    configuration
                        .manageButtonTitle
                ) {
                    onManagePlaces()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    var registrationSheet:
        some View {

        if let placeStore {
            let registrationService =
                PlaceRegistrationService(
                    locationProvider:
                        locationProvider,
                    wifiProvider:
                        wifiProvider,
                    placeStore:
                        placeStore
                )

            let duplicateCheckService =
                PlaceDuplicateCheckService(
                    placeStore:
                        placeStore
                )

            NavigationView {
                PlaceRegistrationView(
                    registrationService:
                        registrationService,
                    duplicateCheckService:
                        duplicateCheckService
                ) { place in
                    isShowingRegistration =
                        false

                    Task {
                        await refreshAfterRegistration(
                            place
                        )
                    }
                }
                .navigationTitle(
                    configuration
                        .registrationNavigationTitle
                )
                .navigationBarTitleDisplayMode(
                    .inline
                )
            }
            .navigationViewStyle(.stack)
        } else {
            EmptyView()
        }
    }

    func refreshAfterRegistration(
        _ place: RegisteredPlace
    ) async {
        if let visitManager {
            try? await visitManager
                .refreshBackgroundRecognition()

            try? await visitManager
                .refresh()
        }

        onRegistered(place)
    }
}

@MainActor
private struct PlaceRecognitionCardStatusView:
    View {

    @ObservedObject
    var visitManager:
        PlaceVisitManager

    let unregisteredMessage:
        String

    var body: some View {
        if let place =
            visitManager
                .recognizedPlaces
                .first?
                .place
        {
            Label(
                "\(place.name.value)에 있습니다.",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(.title3.bold())
        } else if !visitManager
            .activeVisits
            .isEmpty
        {
            Label(
                "등록된 장소에 있습니다.",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(.title3.bold())
        } else {
            Text(
                unregisteredMessage
            )
            .foregroundStyle(.secondary)
        }
    }
}

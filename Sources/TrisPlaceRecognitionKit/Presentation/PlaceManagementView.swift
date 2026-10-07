//
//  PlaceManagementView.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import SwiftUI
import TrisLocationKit

@MainActor
public struct PlaceManagementView: View {

    @State
    private var activeSheet:
        ActiveSheet?

    @State
    private var refreshToken =
        UUID()

    private let placeStore:
        any PlaceStoring

    private let visitManager:
        PlaceVisitManager?

    private let registrationService:
        PlaceRegistrationService

    private let duplicateCheckService:
        PlaceDuplicateCheckService

    private let managementService:
        PlaceManagementService

    private let networkManagementService:
        PlaceNetworkManagementService

    public init(
        placeStore:
            any PlaceStoring,
        locationProvider:
            any LocationProviding,
        wifiProvider:
            any WiFiProviding,
        visitManager:
            PlaceVisitManager? = nil
    ) {

        self.placeStore =
            placeStore

        self.visitManager =
            visitManager

        self.registrationService =
            PlaceRegistrationService(
                locationProvider:
                    locationProvider,
                wifiProvider:
                    wifiProvider,
                placeStore:
                    placeStore
            )

        self.duplicateCheckService =
            PlaceDuplicateCheckService(
                placeStore:
                    placeStore
            )

        self.managementService =
            PlaceManagementService(
                placeStore:
                    placeStore,
                locationProvider:
                    locationProvider
            )

        self.networkManagementService =
            PlaceNetworkManagementService(
                placeStore:
                    placeStore,
                wifiProvider:
                    wifiProvider
            )
    }

    public var body:
        some View {

        NavigationView {

            if let visitManager {

                PlaceManagementObservedContent(
                    placeStore:
                        placeStore,
                    visitManager:
                        visitManager,
                    refreshToken:
                        refreshToken
                ) { place in

                    activeSheet =
                        .detail(
                            place
                        )
                }
                .navigationTitle(\n                    PlaceL10n.string("place.navigation_title")\n                )
                .toolbar {
                    addPlaceToolbar
                }

            } else {

                PlaceListView(
                    placeStore:
                        placeStore,
                    refreshToken:
                        refreshToken
                ) { place in

                    activeSheet =
                        .detail(
                            place
                        )
                }
                .navigationTitle(\n                    PlaceL10n.string("place.navigation_title")\n                )
                .toolbar {
                    addPlaceToolbar
                }
            }
        }
        .navigationViewStyle(
            .stack
        )
        .sheet(
            item:
                $activeSheet,
            onDismiss: {

                refreshToken =
                    UUID()
            }
        ) { sheet in

            switch sheet {

            case .registration:

                registrationSheet

            case .detail(
                let place
            ):

                detailSheet(
                    for:
                        place
                )
            }
        }
    }
}

private extension PlaceManagementView {

    enum ActiveSheet:
        Identifiable {

        case registration
        case detail(
            RegisteredPlace
        )

        var id:
            String {

            switch self {

            case .registration:

                return "registration"

            case .detail(
                let place
            ):

                return "detail-\(place.id.uuidString)"
            }
        }
    }

    @ToolbarContentBuilder
    var addPlaceToolbar:
        some ToolbarContent {

        ToolbarItem(
            placement:
                .navigationBarTrailing
        ) {

            Button {

                activeSheet =
                    .registration

            } label: {

                Label(\n                    PlaceL10n.string("place.add"),
                    systemImage:
                        "plus"
                )
            }
        }
    }

    var registrationSheet:
        some View {

        NavigationView {

            PlaceRegistrationView(
                registrationService:
                    registrationService,
                duplicateCheckService:
                    duplicateCheckService
            ) { _ in

                refreshToken =
                    UUID()

                refreshBackgroundRecognitionAfterPlaceMutation()

                activeSheet =
                    nil
            }
            .navigationTitle(\n                PlaceL10n.string("place.registration.title")\n            )
            .navigationBarTitleDisplayMode(
                .inline
            )
        }
        .navigationViewStyle(
            .stack
        )
    }

    func detailSheet(
        for place:
            RegisteredPlace
    ) -> some View {

        NavigationView {

            PlaceDetailView(
                place:
                    place,
                managementService:
                    managementService,
                networkManagementService:
                    networkManagementService,
                duplicateCheckService:
                    duplicateCheckService,
                onChanged: { _ in

                    refreshToken =
                        UUID()

                    refreshBackgroundRecognitionAfterPlaceMutation()
                },
                onDeleted: { _ in

                    refreshToken =
                        UUID()

                    refreshBackgroundRecognitionAfterPlaceMutation()

                    activeSheet =
                        nil
                }
            )
        }
        .navigationViewStyle(
            .stack
        )
    }

    func refreshBackgroundRecognitionAfterPlaceMutation() {

        guard let visitManager
        else {
            return
        }

        Task {

            try? await visitManager
                .refreshBackgroundRecognition()

            try? await visitManager
                .refresh()
        }
    }
}

@MainActor
private struct PlaceManagementObservedContent:
    View {

    private let placeStore:
        any PlaceStoring

    @ObservedObject
    private var visitManager:
        PlaceVisitManager

    private let refreshToken:
        UUID

    private let onSelect:
        @MainActor (
            RegisteredPlace
        ) -> Void

    init(
        placeStore:
            any PlaceStoring,
        visitManager:
            PlaceVisitManager,
        refreshToken:
            UUID,
        onSelect:
            @escaping @MainActor (
                RegisteredPlace
            ) -> Void
    ) {

        self.placeStore =
            placeStore

        _visitManager =
            ObservedObject(
                wrappedValue:
                    visitManager
            )

        self.refreshToken =
            refreshToken

        self.onSelect =
            onSelect
    }

    var body:
        some View {

        PlaceListView(
            placeStore:
                placeStore,
            refreshToken:
                refreshToken,
            activeVisits:
                visitManager.activeVisits,
            recognizedPlaces:
                visitManager.recognizedPlaces,
            onSelect:
                onSelect
        )
    }
}

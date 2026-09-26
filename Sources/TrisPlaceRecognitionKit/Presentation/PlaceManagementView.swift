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
    private var activeSheet: ActiveSheet?

    @State
    private var refreshToken = UUID()

    private let placeStore: any PlaceStoring

    private let registrationService: PlaceRegistrationService

    private let duplicateCheckService: PlaceDuplicateCheckService

    private let managementService: PlaceManagementService

    private let networkManagementService: PlaceNetworkManagementService

    public init(
        placeStore: any PlaceStoring,
        locationProvider: any LocationProviding,
        wifiProvider: any WiFiProviding
    ) {
        self.placeStore = placeStore

        self.registrationService = PlaceRegistrationService(
            locationProvider: locationProvider,
            wifiProvider: wifiProvider,
            placeStore: placeStore
        )

        self.duplicateCheckService = PlaceDuplicateCheckService(
            placeStore: placeStore
        )

        self.managementService = PlaceManagementService(
            placeStore: placeStore,
            locationProvider: locationProvider
        )

        self.networkManagementService =
            PlaceNetworkManagementService(
                placeStore: placeStore,
                wifiProvider: wifiProvider
            )
    }

    public var body: some View {
        NavigationView {
            PlaceListView(
                placeStore: placeStore,
                refreshToken: refreshToken
            ) { place in
                activeSheet = .detail(place)
            }
            .navigationTitle("장소")
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button {
                        activeSheet = .registration
                    } label: {
                        Label(
                            "장소 추가",
                            systemImage: "plus"
                        )
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(
            item: $activeSheet,
            onDismiss: {
                refreshToken = UUID()
            }
        ) { sheet in
            switch sheet {
            case .registration:
                registrationSheet

            case .detail(let place):
                detailSheet(for: place)
            }
        }
    }
}

private extension PlaceManagementView {

    enum ActiveSheet: Identifiable {
        case registration
        case detail(RegisteredPlace)

        var id: String {
            switch self {
            case .registration:
                return "registration"

            case .detail(let place):
                return "detail-\(place.id.uuidString)"
            }
        }
    }

    var registrationSheet: some View {
        NavigationView {
            PlaceRegistrationView(
                registrationService: registrationService,
                duplicateCheckService: duplicateCheckService
            ) { _ in
                refreshToken = UUID()
                activeSheet = nil
            }
            .navigationTitle("장소 등록")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    func detailSheet(
        for place: RegisteredPlace
    ) -> some View {
        NavigationView {
            PlaceDetailView(
                place: place,
                managementService: managementService,
                networkManagementService: networkManagementService,
                onChanged: { _ in
                    refreshToken = UUID()
                },
                onDeleted: { _ in
                    refreshToken = UUID()
                    activeSheet = nil
                }
            )
        }
        .navigationViewStyle(.stack)
    }
}

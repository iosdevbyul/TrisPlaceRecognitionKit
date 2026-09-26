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
    private var isShowingRegistration = false

    @State
    private var refreshToken = UUID()

    private let placeStore: any PlaceStoring

    private let registrationService: PlaceRegistrationService

    private let duplicateCheckService: PlaceDuplicateCheckService

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
    }

    public var body: some View {
        NavigationView {
            PlaceListView(
                placeStore: placeStore,
                refreshToken: refreshToken
            )
            .navigationTitle("장소")
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button {
                        isShowingRegistration = true
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
            isPresented: $isShowingRegistration
        ) {
            NavigationView {
                PlaceRegistrationView(
                    registrationService: registrationService,
                    duplicateCheckService: duplicateCheckService
                ) { _ in
                    // Registration completed.
                    // Refresh the list and close the sheet.
                    refreshToken = UUID()
                    isShowingRegistration = false
                }
                .navigationTitle("장소 등록")
                .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(.stack)
        }
    }
}

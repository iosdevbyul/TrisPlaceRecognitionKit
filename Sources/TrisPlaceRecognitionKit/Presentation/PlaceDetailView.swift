//
//  PlaceDetailView.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import SwiftUI

@MainActor
public struct PlaceDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var viewModel: PlaceDetailViewModel

    @State
    private var isShowingDeleteConfirmation = false

    @State
    private var isShowingWiFiRemovalConfirmation = false

    @State
    private var networkToRemove: PlaceNetworkIdentity?

    private let onChanged: @MainActor (RegisteredPlace) -> Void
    private let onDeleted: @MainActor (UUID) -> Void

    public init(
        place: RegisteredPlace,
        managementService: PlaceManagementService,
        networkManagementService: PlaceNetworkManagementService,
        duplicateCheckService: PlaceDuplicateCheckService,
        onChanged: @escaping @MainActor (RegisteredPlace) -> Void = { _ in },
        onDeleted: @escaping @MainActor (UUID) -> Void = { _ in }
    ) {
        _viewModel = StateObject(
            wrappedValue: PlaceDetailViewModel(
                place: place,
                managementService: managementService,
                networkManagementService: networkManagementService,
                duplicateCheckService: duplicateCheckService
            )
        )

        self.onChanged = onChanged
        self.onDeleted = onDeleted
    }

    public var body: some View {
        Form {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    Button(PlaceL10n.string("common.confirm")) {
                        viewModel.clearError()
                    }
                }
            }

            nameSection

            radiusSection

            locationSection
            
            if !viewModel.duplicateWarnings.isEmpty
                || viewModel.duplicateWarningErrorMessage != nil {
                duplicateWarningsSection
            }

            wifiSection

            deleteSection
        }
        .navigationTitle(viewModel.place.name.value)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .cancellationAction
            ) {
                Button(PlaceL10n.string("common.close")) {
                    dismiss()
                }
                .disabled(viewModel.isWorking)
            }
        }
        .interactiveDismissDisabled(viewModel.isWorking)
        .alert(
            PlaceL10n.string("place.detail.delete_title"),
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(
                PlaceL10n.string("common.delete"),
                role: .destructive
            ) {
                Task {
                    await viewModel.deletePlace()
                }
            }

            Button(
                PlaceL10n.string("common.cancel"),
                role: .cancel
            ) {}
        } message: {
            Text(
                PlaceL10n.format(
                    "place.detail.delete_message",
                    viewModel.place.name.value
                )
            )
        }
        .confirmationDialog(
            PlaceL10n.string("place.detail.wifi_remove_title"),
            isPresented: $isShowingWiFiRemovalConfirmation,
            titleVisibility: .visible
        ) {
            if let networkToRemove {
                Button(
                    PlaceL10n.string("place.detail.wifi_remove_title"),
                    role: .destructive
                ) {
                    let network = networkToRemove

                    self.networkToRemove = nil

                    Task {
                        await viewModel.removeNetwork(
                            network
                        )
                    }
                }
            }

            Button(
                PlaceL10n.string("common.cancel"),
                role: .cancel
            ) {
                networkToRemove = nil
            }
        } message: {
            Text(
                PlaceL10n.string(
                    "place.detail.wifi_remove_message"
                )
            )
        }
        .onChange(of: viewModel.place) { updated in
            onChanged(updated)
        }
        .onChange(of: viewModel.didDelete) { deleted in
            guard deleted else {
                return
            }

            onDeleted(viewModel.place.id)
            dismiss()
        }
        .task {
            await viewModel.refreshDuplicateWarnings()
        }
    }
}

private extension PlaceDetailView {
    
    var duplicateWarningsSection: some View {
        Section(PlaceL10n.string("place.detail.duplicate_section")) {
            if let error = viewModel.duplicateWarningErrorMessage {
                Text(PlaceL10n.string("place.detail.duplicate_failed"))
                    .foregroundStyle(.red)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(PlaceL10n.string("common.retry")) {
                    Task {
                        await viewModel.refreshDuplicateWarnings()
                    }
                }
            }

            ForEach(
                viewModel.duplicateWarnings.indices,
                id: \.self
            ) { index in
                let warning = viewModel.duplicateWarnings[index]

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {
                    Text(warning.existingPlace.name.value)
                        .font(.headline)

                    ForEach(
                        warning.reasons.indices,
                        id: \.self
                    ) { reasonIndex in
                        Text(
                            duplicateReasonDescription(
                                warning.reasons[reasonIndex]
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if !viewModel.duplicateWarnings.isEmpty {
                Text(
                    PlaceL10n.string(
                        "place.detail.duplicate_info"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    func duplicateReasonDescription(
        _ reason: PlaceDuplicateReason
    ) -> String {
        switch reason {
        case .sameBSSID:
            return PlaceL10n.string("place.duplicate.same_bssid")

        case .sameSSID:
            return PlaceL10n.string("place.duplicate.same_ssid")

        case .overlappingGPS(let distance):
            return String(
                format: PlaceL10n.string("place.duplicate.overlap"),
                distance
            )
        }
    }

    var nameSection: some View {
        Section(PlaceL10n.string("place.name")) {
            TextField(
                PlaceL10n.string("place.name"),
                text: $viewModel.name
            )
            .disabled(viewModel.isWorking)

            Text(
                PlaceL10n.format(
                    "place.name.max_length",
                    PlaceName.maximumLength
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(PlaceL10n.string("place.detail.save_name")) {
                Task {
                    await viewModel.rename()
                }
            }
            .disabled(!viewModel.canRename)
        }
    }

    var radiusSection: some View {
        Section(PlaceL10n.string("place.recognition_radius")) {
            HStack {
                Text(PlaceL10n.string("place.radius.label"))

                Spacer()

                TextField(
                    PlaceL10n.string("place.radius.label"),
                    value: $viewModel.recognitionRadius,
                    format: .number
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .disabled(viewModel.isWorking)

                Text("m")
            }

            Text(
                viewModel.place.location.map {
                    PlaceL10n.format(
                        "place.detail.saved_radius",
                        Int($0.recognitionRadius)
                    )
                } ?? PlaceL10n.string("place.gps_not_registered")
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(PlaceL10n.string("place.detail.save_radius")) {
                Task {
                    await viewModel.updateRadius()
                }
            }
            .disabled(!viewModel.canUpdateRadius)
        }
    }

    var locationSection: some View {
        Section(PlaceL10n.string("place.detail.location_section")) {
            if let location = viewModel.place.location {
                detailRow(
                    PlaceL10n.string("place.latitude"),
                    value: String(
                        format: "%.5f",
                        location.latitude
                    )
                )

                detailRow(
                    PlaceL10n.string("place.longitude"),
                    value: String(
                        format: "%.5f",
                        location.longitude
                    )
                )
            } else {
                Text(PlaceL10n.string("place.gps_not_registered"))
                    .foregroundStyle(.secondary)
            }

            Button(PlaceL10n.string("place.detail.update_location")) {
                Task {
                    await viewModel.updateCurrentLocation()
                }
            }
            .disabled(
                viewModel.isWorking || viewModel.didDelete
            )

            Text(
                PlaceL10n.string(
                    "place.detail.update_location_info"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var wifiSection: some View {
        Section(PlaceL10n.string("place.detail.wifi_section")) {
            if viewModel.place.networkIdentities.isEmpty {
                Text(PlaceL10n.string("place.detail.wifi_empty"))
                    .foregroundStyle(.secondary)

                Text(PlaceL10n.string("place.detail.gps_only_info"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    viewModel.place.networkIdentities.indices,
                    id: \.self
                ) { index in
                    let network =
                        viewModel.place.networkIdentities[index]

                    HStack(spacing: 12) {
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(
                                network.ssid ?? PlaceL10n.string("place.ssid.none")
                            )
                            .font(.body)

                            if let bssid = network.bssid {
                                Text(bssid)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button(
                            PlaceL10n.string("place.detail.remove"),
                            role: .destructive
                        ) {
                            networkToRemove = network

                            isShowingWiFiRemovalConfirmation = true
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.isWorking)
                    }
                }
            }

            Button(PlaceL10n.string("place.detail.add_current_wifi")) {
                Task {
                    await viewModel.addCurrentWiFi()
                }
            }
            .disabled(
                viewModel.isWorking || viewModel.didDelete
            )

            Text(
                PlaceL10n.string(
                    "place.detail.wifi_add_info"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var deleteSection: some View {
        Section {
            Button(
                PlaceL10n.string("place.detail.delete"),
                role: .destructive
            ) {
                isShowingDeleteConfirmation = true
            }
            .disabled(
                viewModel.isWorking || viewModel.didDelete
            )
        }
    }

    func detailRow(
        _ title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)

            Spacer(minLength: 12)

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

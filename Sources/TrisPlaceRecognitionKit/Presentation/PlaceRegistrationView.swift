//
//  PlaceRegistrationView.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import SwiftUI

@MainActor
public struct PlaceRegistrationView: View {
    @Environment(\.dismiss)
    private var dismiss
    @StateObject
    private var viewModel: PlaceRegistrationViewModel

    private let onRegistered: @MainActor (RegisteredPlace) -> Void

    public init(
        registrationService: PlaceRegistrationService,
        duplicateCheckService: PlaceDuplicateCheckService,
        onRegistered: @escaping @MainActor (RegisteredPlace) -> Void = { _ in }
    ) {
        _viewModel = StateObject(
            wrappedValue: PlaceRegistrationViewModel(
                registrationService: registrationService,
                duplicateCheckService: duplicateCheckService
            )
        )

        self.onRegistered = onRegistered
    }

    public var body: some View {
        Group {
            switch viewModel.phase {
            case .editing, .preparing:
                editingForm

            case .reviewing, .saving:
                reviewForm

            case .completed:
                completionView
            }
        }
        .onChange(of: viewModel.registeredPlace?.id) { _ in
            guard let registeredPlace = viewModel.registeredPlace else {
                return
            }

            onRegistered(registeredPlace)
        }
        .toolbar {
            ToolbarItem(
                placement: .cancellationAction
            ) {
                if viewModel.phase != .completed {
                    Button(PlaceL10n.string("common.close")) {
                        viewModel.cancelPreview()
                        dismiss()
                    }
                    .disabled(viewModel.phase == .saving)
                }
            }
        }
        .interactiveDismissDisabled(
            viewModel.phase == .saving
        )
        .onDisappear {
            viewModel.cancelPreview()
        }
    }
}

private extension PlaceRegistrationView {

    var editingForm: some View {
        Form {
            Section(PlaceL10n.string("place.name")) {
                TextField(
                    PlaceL10n.string("place.name.placeholder"),
                    text: $viewModel.name
                )
                .disabled(viewModel.phase == .preparing)

                Text(\n                    PlaceL10n.format(\n                        "place.name.max_length",\n                        PlaceName.maximumLength\n                    )\n                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(PlaceL10n.string("place.registration.method")) {
                Picker(
                    PlaceL10n.string("place.registration.method.label"),
                    selection: $viewModel.method
                ) {
                    Text(PlaceL10n.string("place.registration.automatic"))
                        .tag(PlaceRegistrationMethod.automatic)

                    Text("Wi-Fi")
                        .tag(PlaceRegistrationMethod.wifi)

                    Text(PlaceL10n.string("place.gps_only"))
                        .tag(PlaceRegistrationMethod.gpsOnly)
                }
                .disabled(viewModel.phase == .preparing)

                Text(methodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(PlaceL10n.string("place.recognition_radius")) {
                Picker(
                    PlaceL10n.string("place.radius.label"),
                    selection: $viewModel.recognitionRadius
                ) {
                    Text("50m").tag(50.0)
                    Text("100m").tag(100.0)
                    Text("200m").tag(200.0)
                    Text("500m").tag(500.0)
                }
                .disabled(viewModel.phase == .preparing)
            }

            Section {
                Text(
                    PlaceL10n.string(
                        "place.registration.collection_description"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.phase == .preparing {
                    ProgressView(PlaceL10n.string("place.registration.preparing"))

                    Button(PlaceL10n.string("common.cancel")) {
                        viewModel.cancelPreview()
                    }
                } else {
                    Button(PlaceL10n.string("place.registration.review")) {
                        Task {
                            await viewModel.prepare()
                        }
                    }
                    .disabled(!viewModel.canPrepare)
                }
            }
        }
    }

    var reviewForm: some View {
        Form {
            if let candidate = viewModel.candidate {
                Section(PlaceL10n.string("place.registration.info")) {
                    detailRow(
                        PlaceL10n.string("place.name"),
                        value: candidate.name.value
                    )

                    detailRow(
                        PlaceL10n.string("place.recognition_radius"),
                        value: candidate.location.map {
                            "\(Int($0.recognitionRadius))m"
                        } ?? PlaceL10n.string(
                            "place.gps_not_registered"
                        )
                    )

                    detailRow(
                        PlaceL10n.string("place.latitude"),
                        value: String(
                            format: "%.5f",
                            candidate.location?.latitude ?? 0
                        )
                    )

                    detailRow(
                        PlaceL10n.string("place.longitude"),
                        value: String(
                            format: "%.5f",
                            candidate.location?.longitude ?? 0
                        )
                    )
                }

                Section("Wi-Fi") {
                    if candidate.networkIdentities.isEmpty {
                        Text(PlaceL10n.string("place.wifi.none"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(
                            candidate.networkIdentities,
                            id: \.self
                        ) { network in
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text(network.ssid ?? PlaceL10n.string("place.ssid.none"))

                                if let bssid = network.bssid {
                                    Text(bssid)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !viewModel.warnings.isEmpty {
                    Section(PlaceL10n.string("place.duplicate_warning")) {
                        Text(
                            PlaceL10n.string(
                                "place.duplicate_description"
                            )
                        )
                        .font(.subheadline)

                        ForEach(
                            viewModel.warnings.indices,
                            id: \.self
                        ) { index in
                            let warning = viewModel.warnings[index]

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
                                        description(
                                            for: warning.reasons[reasonIndex]
                                        )
                                    )
                                    .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.phase == .saving {
                    ProgressView(PlaceL10n.string("place.registration.saving"))
                } else {
                    Button(PlaceL10n.string("place.registration.register")) {
                        Task {
                            await viewModel.confirmRegistration()
                        }
                    }

                    Button(PlaceL10n.string("common.edit")) {
                        viewModel.cancelPreview()
                    }
                }
            }
        }
    }

    var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text(PlaceL10n.string("place.registration.completed"))
                .font(.headline)

            if let name = viewModel.registeredPlace?.name.value {
                Text(name)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    var methodDescription: String {
        switch viewModel.method {
        case .automatic:
            return PlaceL10n.string("place.method.automatic.description")

        case .wifi:
            return PlaceL10n.string("place.method.wifi.description")

        case .gpsOnly:
            return PlaceL10n.string("place.method.gps.description")
        }
    }

    func description(
        for reason: PlaceDuplicateReason
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
    
    @ViewBuilder
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

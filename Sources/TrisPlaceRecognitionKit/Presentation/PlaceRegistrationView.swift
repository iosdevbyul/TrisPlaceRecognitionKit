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
                    Button("닫기") {
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
            Section("장소 이름") {
                TextField(
                    "예: 헬스장",
                    text: $viewModel.name
                )
                .disabled(viewModel.phase == .preparing)

                Text("최대 \(PlaceName.maximumLength)자")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("등록 방식") {
                Picker(
                    "인식 방식",
                    selection: $viewModel.method
                ) {
                    Text("자동")
                        .tag(PlaceRegistrationMethod.automatic)

                    Text("Wi-Fi")
                        .tag(PlaceRegistrationMethod.wifi)

                    Text("GPS 전용")
                        .tag(PlaceRegistrationMethod.gpsOnly)
                }
                .disabled(viewModel.phase == .preparing)

                Text(methodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("인식 반경") {
                Picker(
                    "반경",
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
                    "등록 정보를 확인할 때 현재 위치와 " +
                    "선택한 방식에 필요한 네트워크 정보를 수집합니다."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.phase == .preparing {
                    ProgressView("등록 정보 확인 중")

                    Button("취소") {
                        viewModel.cancelPreview()
                    }
                } else {
                    Button("등록 정보 확인") {
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
                Section("등록 정보") {
                    detailRow(
                        "장소 이름",
                        value: candidate.name.value
                    )

                    detailRow(
                        "인식 반경",
                        value: "\(Int(candidate.location.recognitionRadius))m"
                    )

                    detailRow(
                        "위도",
                        value: String(
                            format: "%.5f",
                            candidate.location.latitude
                        )
                    )

                    detailRow(
                        "경도",
                        value: String(
                            format: "%.5f",
                            candidate.location.longitude
                        )
                    )
                }

                Section("Wi-Fi") {
                    if candidate.networkIdentities.isEmpty {
                        Text("저장되는 Wi-Fi 정보 없음")
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
                                Text(network.ssid ?? "SSID 없음")

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
                    Section("중복 장소 경고") {
                        Text(
                            "비슷한 장소가 이미 등록되어 있습니다. " +
                            "확인 후에도 새 장소를 등록할 수 있습니다."
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
                    ProgressView("장소 등록 중")
                } else {
                    Button("장소 등록") {
                        Task {
                            await viewModel.confirmRegistration()
                        }
                    }

                    Button("수정하기") {
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

            Text("장소가 등록되었습니다")
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
            return "현재 Wi-Fi가 확인되면 함께 저장하고, 없으면 GPS만 사용합니다."

        case .wifi:
            return "현재 연결된 Wi-Fi를 반드시 확인한 뒤 등록합니다."

        case .gpsOnly:
            return "Wi-Fi를 저장하지 않고 GPS 위치만 사용합니다."
        }
    }

    func description(
        for reason: PlaceDuplicateReason
    ) -> String {
        switch reason {
        case .sameBSSID:
            return "동일한 Wi-Fi 공유기가 등록되어 있습니다."

        case .sameSSID:
            return "동일한 Wi-Fi 이름이 등록되어 있습니다."

        case .overlappingGPS(let distance):
            return String(
                format: "인식 영역이 겹칩니다. 중심 간 거리: %.0fm",
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

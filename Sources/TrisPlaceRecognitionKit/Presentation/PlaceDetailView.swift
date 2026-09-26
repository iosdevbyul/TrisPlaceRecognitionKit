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

                    Button("확인") {
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
                Button("닫기") {
                    dismiss()
                }
                .disabled(viewModel.isWorking)
            }
        }
        .interactiveDismissDisabled(viewModel.isWorking)
        .alert(
            "장소 삭제",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button(
                "삭제",
                role: .destructive
            ) {
                Task {
                    await viewModel.deletePlace()
                }
            }

            Button(
                "취소",
                role: .cancel
            ) {}
        } message: {
            Text(
                "'\(viewModel.place.name.value)' 장소를 삭제하시겠습니까? " +
                "삭제한 장소는 복구할 수 없습니다."
            )
        }
        .confirmationDialog(
            "Wi-Fi 제거",
            isPresented: $isShowingWiFiRemovalConfirmation,
            titleVisibility: .visible
        ) {
            if let networkToRemove {
                Button(
                    "Wi-Fi 제거",
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
                "취소",
                role: .cancel
            ) {
                networkToRemove = nil
            }
        } message: {
            Text(
                "선택한 Wi-Fi를 이 장소의 인식 대상에서 제거합니다."
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
        Section("다른 장소와 인식 대상 중복") {
            if let error = viewModel.duplicateWarningErrorMessage {
                Text("중복 검사를 완료하지 못했습니다.")
                    .foregroundStyle(.red)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("다시 검사") {
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
                    "중복 경고는 정보 제공용입니다. " +
                    "현재 장소의 설정은 자동으로 변경되지 않습니다."
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

    var nameSection: some View {
        Section("장소 이름") {
            TextField(
                "장소 이름",
                text: $viewModel.name
            )
            .disabled(viewModel.isWorking)

            Text(
                "최대 \(PlaceName.maximumLength)자"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("이름 저장") {
                Task {
                    await viewModel.rename()
                }
            }
            .disabled(!viewModel.canRename)
        }
    }

    var radiusSection: some View {
        Section("인식 반경") {
            HStack {
                Text("반경")

                Spacer()

                TextField(
                    "반경",
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
                "현재 저장된 반경: " +
                "\(Int(viewModel.place.location.recognitionRadius))m"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("인식 반경 저장") {
                Task {
                    await viewModel.updateRadius()
                }
            }
            .disabled(!viewModel.canUpdateRadius)
        }
    }

    var locationSection: some View {
        Section("등록된 위치") {
            detailRow(
                "위도",
                value: String(
                    format: "%.5f",
                    viewModel.place.location.latitude
                )
            )

            detailRow(
                "경도",
                value: String(
                    format: "%.5f",
                    viewModel.place.location.longitude
                )
            )

            Button("현재 위치로 변경") {
                Task {
                    await viewModel.updateCurrentLocation()
                }
            }
            .disabled(
                viewModel.isWorking || viewModel.didDelete
            )

            Text(
                "현재 위치를 다시 측정하고 위치 정확도를 " +
                "확인한 뒤 저장합니다."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var wifiSection: some View {
        Section("등록된 Wi-Fi") {
            if viewModel.place.networkIdentities.isEmpty {
                Text("등록된 Wi-Fi가 없습니다.")
                    .foregroundStyle(.secondary)

                Text("현재 이 장소는 GPS만 사용합니다.")
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
                                network.ssid ?? "SSID 없음"
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
                            "제거",
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

            Button("현재 Wi-Fi 추가") {
                Task {
                    await viewModel.addCurrentWiFi()
                }
            }
            .disabled(
                viewModel.isWorking || viewModel.didDelete
            )

            Text(
                "현재 연결된 Wi-Fi만 추가할 수 있습니다. " +
                "직접 SSID를 입력하는 기능은 제공하지 않습니다."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var deleteSection: some View {
        Section {
            Button(
                "장소 삭제",
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

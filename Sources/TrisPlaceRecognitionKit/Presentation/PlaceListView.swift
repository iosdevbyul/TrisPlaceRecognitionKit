//
//  PlaceListView.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import SwiftUI

@MainActor
public struct PlaceListView: View {

    @StateObject
    private var viewModel: PlaceListViewModel

    private let refreshToken: UUID?

    private let onSelect: (
        @MainActor (RegisteredPlace) -> Void
    )?

    public init(
        placeStore: any PlaceStoring,
        refreshToken: UUID? = nil,
        onSelect: (
            @MainActor (RegisteredPlace) -> Void
        )? = nil
    ) {
        self.refreshToken = refreshToken
        self.onSelect = onSelect

        _viewModel = StateObject(
            wrappedValue: PlaceListViewModel(
                placeStore: placeStore
            )
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .font(.subheadline)

                    Button("다시 시도") {
                        Task {
                            await viewModel.load()
                        }
                    }
                }
                .padding()
            }

            if viewModel.isLoading && viewModel.places.isEmpty {
                Spacer()

                ProgressView("장소 불러오는 중")

                Spacer()
            } else if viewModel.places.isEmpty {
                Spacer()

                Text("등록된 장소가 없습니다")
                    .foregroundStyle(.secondary)

                Button("새로고침") {
                    Task {
                        await viewModel.load()
                    }
                }
                .padding(.top, 8)

                Spacer()
            } else {
                List(viewModel.places) { place in
                    if let onSelect {
                        Button {
                            onSelect(place)
                        } label: {
                            placeRow(place)
                        }
                        .buttonStyle(.plain)
                    } else {
                        placeRow(place)
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: refreshToken) { _ in
            Task {
                await viewModel.load()
            }
        }
    }
    
    private func placeRow(
        _ place: RegisteredPlace
    ) -> some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                Text(place.name.value)
                    .font(.headline)

                Text(
                    place.networkIdentities.isEmpty
                        ? "GPS 전용"
                        : "Wi-Fi \(place.networkIdentities.count)개"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(
                    "인식 반경: " +
                    "\(Int(place.location.recognitionRadius))m"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if onSelect != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

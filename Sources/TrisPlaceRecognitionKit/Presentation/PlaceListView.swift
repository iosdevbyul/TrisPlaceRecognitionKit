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
    private var viewModel:
        PlaceListViewModel

    private let refreshToken:
        UUID?

    private let activeVisits:
        [PlaceVisitRecord]

    private let recognizedPlaces:
        [RecognizedPlace]

    private let onSelect:
        (
            @MainActor (
                RegisteredPlace
            ) -> Void
        )?

    public init(
        placeStore:
            any PlaceStoring,
        refreshToken:
            UUID? = nil,
        activeVisits:
            [PlaceVisitRecord] = [],
        recognizedPlaces:
            [RecognizedPlace] = [],
        onSelect:
            (
                @MainActor (
                    RegisteredPlace
                ) -> Void
            )? = nil
    ) {

        self.refreshToken =
            refreshToken

        self.activeVisits =
            activeVisits

        self.recognizedPlaces =
            recognizedPlaces

        self.onSelect =
            onSelect

        _viewModel =
            StateObject(
                wrappedValue:
                    PlaceListViewModel(
                        placeStore:
                            placeStore
                    )
            )
    }

    public var body:
        some View {

        VStack(
            spacing: 0
        ) {

            if let errorMessage =
                viewModel.errorMessage {

                VStack(
                    spacing: 12
                ) {

                    Text(
                        errorMessage
                    )
                    .font(
                        .subheadline
                    )

                    Button(
                        "다시 시도"
                    ) {

                        Task {

                            await viewModel
                                .load()
                        }
                    }
                }
                .padding()
            }

            if viewModel.isLoading
                && viewModel.places.isEmpty {

                Spacer()

                ProgressView(
                    "장소 불러오는 중"
                )

                Spacer()

            } else if viewModel.places.isEmpty {

                Spacer()

                Text(
                    "등록된 장소가 없습니다"
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    "새로고침"
                ) {

                    Task {

                        await viewModel
                            .load()
                    }
                }
                .padding(
                    .top,
                    8
                )

                Spacer()

            } else {

                List(
                    viewModel.places
                ) { place in

                    if let onSelect {

                        Button {

                            onSelect(
                                place
                            )

                        } label: {

                            placeRow(
                                place
                            )
                        }
                        .buttonStyle(
                            .plain
                        )

                    } else {

                        placeRow(
                            place
                        )
                    }
                }
                .refreshable {

                    await viewModel
                        .load()
                }
            }
        }
        .task {

            await viewModel
                .load()
        }
        .onChange(
            of: refreshToken
        ) { _ in

            Task {

                await viewModel
                    .load()
            }
        }
    }
}

private extension PlaceListView {

    func placeRow(
        _ place:
            RegisteredPlace
    ) -> some View {

        let activeVisit =
            activeVisit(
                for:
                    place.id
            )

        let isRecognized =
            isCurrentlyRecognized(
                place.id
            )

        return HStack(
            spacing: 12
        ) {

            VStack(
                alignment:
                    .leading,
                spacing: 6
            ) {

                Text(
                    place.name.value
                )
                .font(
                    .headline
                )

                if isRecognized {

                    Text(
                        "현재 위치한 장소"
                    )
                    .font(
                        .subheadline
                    )
                    .fontWeight(
                        .semibold
                    )

                    if let activeVisit {

                        Text(
                            "입장 \(formattedEntryTime(activeVisit.startedAt))"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        Text(
                            "현재 감지됨"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Text(
                    place.networkIdentities
                        .isEmpty
                    ? "GPS 전용"
                    : "Wi-Fi \(place.networkIdentities.count)개"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )

                Text(
                    place.location.map {
                        "인식 반경: \(Int($0.recognitionRadius))m"
                    } ?? "GPS 위치 미등록"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            if onSelect != nil {

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(
            .vertical,
            4
        )
        .contentShape(
            Rectangle()
        )
    }

    func activeVisit(
        for placeID:
            UUID
    ) -> PlaceVisitRecord? {

        activeVisits
            .first {
                $0.placeID
                    == placeID
            }
    }

    func isCurrentlyRecognized(
        _ placeID:
            UUID
    ) -> Bool {

        recognizedPlaces
            .contains {
                $0.place.id
                    == placeID
            }
    }

    func formattedEntryTime(
        _ date:
            Date
    ) -> String {

        date.formatted(
            date:
                .abbreviated,
            time:
                .shortened
        )
    }
}

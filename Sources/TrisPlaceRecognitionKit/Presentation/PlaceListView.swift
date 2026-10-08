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
                        PlaceL10n.string("place.retry")
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
                    PlaceL10n.string("place.loading")
                )

                Spacer()

            } else if viewModel.places.isEmpty {

                Spacer()

                Text(
                    PlaceL10n.string("place.empty")
                )
                .foregroundStyle(
                    .secondary
                )

                Button(
                    PlaceL10n.string("place.refresh")
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
                        PlaceL10n.string("place.current")
                    )
                    .font(
                        .subheadline
                    )
                    .fontWeight(
                        .semibold
                    )

                    if let activeVisit {

                        Text(
                            PlaceL10n.format(
                                "place.arrived",
                                formattedEntryTime(activeVisit.startedAt)
                            )
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        Text(
                            PlaceL10n.string("place.detected")
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
                    ? PlaceL10n.string(
                        "place.gps_only"
                    )
                    : PlaceL10n.format(
                        "place.wifi_count",
                        place.networkIdentities.count
                    )
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )

                Text(
                    place.location.map {
                        PlaceL10n.format(
                            "place.radius",
                            Int($0.recognitionRadius)
                        )
                    } ?? PlaceL10n.string(
                        "place.gps_not_registered"
                    )
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

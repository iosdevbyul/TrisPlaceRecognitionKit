//
//  DemoVisitHistoryView.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-10-03.
//

import SwiftUI
import TrisPlaceRecognitionKit

@MainActor
struct DemoVisitHistoryView: View {

    @Environment(\.scenePhase)
    private var scenePhase

    @ObservedObject
    private var visitManager:
        PlaceVisitManager

    private let placeStore:
        any PlaceStoring

    @State
    private var visits:
        [PlaceVisitRecord] = []

    @State
    private var placeNames:
        [UUID: String] = [:]

    @State
    private var isLoading = false

    @State
    private var errorMessage:
        String?

    init(
        placeStore: any PlaceStoring,
        visitManager: PlaceVisitManager
    ) {

        self.placeStore =
            placeStore

        _visitManager =
            ObservedObject(
                wrappedValue:
                    visitManager
            )
    }

    var body: some View {

        NavigationView {

            Group {

                if isLoading
                    && visits.isEmpty {

                    ProgressView(
                        "방문 기록 불러오는 중"
                    )

                } else if visits.isEmpty {

                    emptyView

                } else {

                    visitList
                }
            }
            .navigationTitle(
                "방문 기록"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {

                    Button {

                        Task {

                            await reload()
                        }

                    } label: {

                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }
                    .disabled(
                        isLoading
                    )
                }
            }
        }
        .navigationViewStyle(
            .stack
        )
        .task {

            await reload()
        }
        .onChange(
            of: scenePhase
        ) { phase in

            guard
                phase == .active
            else {
                return
            }

            Task {

                await reload()
            }
        }
    }
}

private extension
    DemoVisitHistoryView {

    var emptyView:
        some View {

        VStack(
            spacing: 12
        ) {

            Image(
                systemName:
                    "clock.arrow.circlepath"
            )
            .font(
                .system(
                    size: 42
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "아직 방문 기록이 없습니다."
            )
            .font(
                .headline
            )

            Text(
                "장소에 들어오고 나가면\n입장·퇴장 시각과 체류시간이 여기에 기록됩니다."
            )
            .font(
                .subheadline
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .center
            )

            if let errorMessage {

                Text(
                    errorMessage
                )
                .foregroundStyle(
                    .red
                )
                .multilineTextAlignment(
                    .center
                )
            }
        }
        .padding()
    }

    var visitList:
        some View {

        List {

            if let errorMessage {

                Section {

                    Text(
                        errorMessage
                    )
                    .foregroundStyle(
                        .red
                    )
                }
            }

            Section(
                "최근 방문"
            ) {

                ForEach(
                    visits,
                    id: \.id
                ) { visit in

                    visitRow(
                        visit
                    )
                }
            }
        }
        .refreshable {

            await reload()
        }
    }

    @ViewBuilder
    func visitRow(
        _ visit:
            PlaceVisitRecord
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack {

                Text(
                    placeName(
                        for:
                            visit.placeID
                    )
                )
                .font(
                    .headline
                )

                Spacer()

                if visit.isActive {

                    Text(
                        "방문 중"
                    )
                    .font(
                        .caption
                    )
                    .fontWeight(
                        .semibold
                    )
                    .foregroundStyle(
                        .blue
                    )

                } else {

                    Text(
                        "완료"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            detailRow(
                title: "입장",
                value:
                    formattedDate(
                        visit.startedAt
                    )
            )

            if let endedAt =
                visit.endedAt {

                detailRow(
                    title: "퇴장",
                    value:
                        formattedDate(
                            endedAt
                        )
                )

                detailRow(
                    title: "체류",
                    value:
                        durationText(
                            endedAt
                                .timeIntervalSince(
                                    visit.startedAt
                                )
                        )
                )

            } else {

                detailRow(
                    title: "퇴장",
                    value:
                        "현재 방문 중"
                )
            }

            detailRow(
                title: "입장 근거",
                value:
                    evidenceText(
                        visit
                            .arrivalEvidence
                    )
            )
        }
        .padding(
            .vertical,
            6
        )
    }

    func detailRow(
        title: String,
        value: String
    ) -> some View {

        HStack(
            alignment: .firstTextBaseline
        ) {

            Text(
                title
            )
            .foregroundStyle(
                .secondary
            )

            Spacer(
                minLength: 12
            )

            Text(
                value
            )
            .multilineTextAlignment(
                .trailing
            )
        }
        .font(
            .subheadline
        )
    }

    func reload() async {

        guard
            !isLoading
        else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {

            isLoading = false
        }

        do {

            let places =
                try await placeStore
                    .fetchAll()

            let fetchedVisits =
                try await visitManager
                    .fetchVisits()

            placeNames =
                Dictionary(
                    uniqueKeysWithValues:
                        places.map {
                            (
                                $0.id,
                                $0.name.value
                            )
                        }
                )

            visits =
                fetchedVisits
                    .sorted {
                        lhs,
                        rhs in

                        if lhs.startedAt
                            != rhs.startedAt {

                            return lhs
                                .startedAt
                                > rhs
                                    .startedAt
                        }

                        return lhs.id
                            .uuidString
                            > rhs.id
                                .uuidString
                    }

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    func placeName(
        for id: UUID
    ) -> String {

        placeNames[id]
            ?? "삭제된 장소"
    }

    func formattedDate(
        _ date: Date
    ) -> String {

        date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    func durationText(
        _ interval:
            TimeInterval
    ) -> String {

        let seconds =
            max(
                0,
                Int(interval)
            )

        if seconds < 60 {

            return "< 1분"
        }

        let minutes =
            seconds / 60

        let hours =
            minutes / 60

        let remainingMinutes =
            minutes % 60

        if hours > 0 {

            return "\(hours)시간 \(remainingMinutes)분"
        }

        return "\(minutes)분"
    }

    func evidenceText(
        _ evidence:
            PlaceRecognitionEvidence
    ) -> String {

        switch evidence {

        case .bssid:
            return "Wi-Fi BSSID"

        case .ssid:
            return "Wi-Fi SSID"

        case .gpsOnlyWiFiUnavailable:
            return "GPS · Wi-Fi 확인 불가"

        case .gpsOnlyNoWiFiConfigured:
            return "GPS"
        }
    }
}

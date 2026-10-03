//
//  DemoBackgroundValidationView.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-10-03.
//

import SwiftUI
import TrisLocationKit
import TrisPlaceRecognitionKit

@MainActor
struct DemoBackgroundValidationView: View {

    @Environment(\.scenePhase)
    private var scenePhase

    @ObservedObject
    private var environment: DemoEnvironment

    @ObservedObject
    private var visitManager: PlaceVisitManager

    private let placeStore: any PlaceStoring

    @State
    private var places: [RegisteredPlace] = []

    @State
    private var events: [PlaceVisitEvent] = []

    @State
    private var currentNetwork: WiFiNetwork?

    @State
    private var isRefreshing = false

    @State
    private var localErrorMessage: String?

    init(
        environment: DemoEnvironment,
        placeStore: any PlaceStoring,
        visitManager: PlaceVisitManager
    ) {
        self.environment = environment
        self.placeStore = placeStore
        self.visitManager = visitManager
    }

    var body: some View {
        NavigationView {
            List {
                authorizationSection

                backgroundRecognitionSection

                currentWiFiSection

                activeVisitSection

                recentEventSection

                controlSection

                validationGuideSection
            }
            .navigationTitle("실기기 검증")
            .toolbar {
                ToolbarItem(
                    placement: .navigationBarTrailing
                ) {
                    Button {
                        Task {
                            await refreshSnapshot()
                        }
                    } label: {
                        Image(
                            systemName: "arrow.clockwise"
                        )
                    }
                    .disabled(isRefreshing)
                }
            }
            .refreshable {
                await refreshSnapshot()
            }
        }
        .navigationViewStyle(.stack)
        .task {
            await refreshSnapshot()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else {
                return
            }

            Task {
                await environment
                    .retryBackgroundRecognition()

                await refreshSnapshot()
            }
        }
    }
}

// MARK: - Sections

private extension DemoBackgroundValidationView {

    var authorizationSection: some View {
        Section("위치 권한") {
            statusRow(
                title: "현재 권한",
                value: authorizationText
            )

            statusRow(
                title: "Background 요구 권한",
                value: "Always"
            )
        }
    }

    var backgroundRecognitionSection: some View {
        Section("Background Recognition") {
            statusRow(
                title: "사용 설정",
                value: environment
                    .wantsBackgroundRecognition
                    ? "ON"
                    : "OFF"
            )

            statusRow(
                title: "Manager 상태",
                value: visitManager
                    .isBackgroundRecognitionEnabled
                    ? "실행 중"
                    : "중지"
            )

            statusRow(
                title: "등록 장소",
                value: "\(places.count)개"
            )

            statusRow(
                title: "Active Visit",
                value:
                    "\(visitManager.activeVisits.count)개"
            )

            statusRow(
                title: "현재 인식 장소",
                value:
                    "\(visitManager.recognizedPlaces.count)개"
            )

            statusRow(
                title: "Location Relaunch",
                value: environment
                    .wasLaunchedForLocationEvent
                    ? "예"
                    : "아니오"
            )

            if let statusMessage =
                environment.statusMessage {

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error =
                visitManager
                    .lastBackgroundErrorMessage {

                Text(error)
                    .foregroundStyle(.red)
            }

            if let localErrorMessage {
                Text(localErrorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    var currentWiFiSection: some View {
        Section("현재 Wi-Fi") {
            if let currentNetwork {
                statusRow(
                    title: "SSID",
                    value: currentNetwork.ssid
                )

                statusRow(
                    title: "BSSID",
                    value:
                        currentNetwork.bssid
                        ?? "확인 불가"
                )
            } else {
                Text(
                    "현재 Wi-Fi 정보를 확인하지 못했습니다."
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    var activeVisitSection: some View {
        Section("현재 방문") {
            if visitManager.activeVisits.isEmpty {
                Text("현재 활성 방문 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    visitManager.activeVisits,
                    id: \.id
                ) { visit in
                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        Text(
                            placeName(
                                for: visit.placeID
                            )
                        )
                        .font(.headline)

                        Text(
                            "입장 \(formattedDate(visit.startedAt))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text(
                            "현재 체류 \(currentDurationText(for: visit))"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
            }
        }
    }

    var recentEventSection: some View {
        Section("최근 ARRIVED / DEPARTED") {
            if events.isEmpty {
                Text("아직 이벤트 없음")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    recentEvents,
                    id: \.id
                ) { event in
                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        HStack {
                            Text(
                                placeName(
                                    for: event.placeID
                                )
                            )
                            .font(.headline)

                            Spacer()

                            Text(
                                eventText(
                                    event.kind
                                )
                            )
                            .font(.caption)
                            .fontWeight(.semibold)
                        }

                        Text(
                            formattedDate(
                                event.occurredAt
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
            }
        }
    }

    var controlSection: some View {
        Section("제어") {
            if visitManager
                .isBackgroundRecognitionEnabled {

                Button(
                    "Background Recognition 끄기",
                    role: .destructive
                ) {
                    Task {
                        await environment
                            .disableBackgroundRecognition()

                        await refreshSnapshot()
                    }
                }
            } else {
                Button(
                    "Background Recognition 켜기"
                ) {
                    Task {
                        await environment
                            .enableBackgroundRecognition()

                        await refreshSnapshot()
                    }
                }
            }

            Button(
                "모니터링 후보 다시 동기화"
            ) {
                Task {
                    await synchronizeCandidates()
                }
            }
            .disabled(
                !visitManager
                    .isBackgroundRecognitionEnabled
            )

            Button(
                "상태 새로고침"
            ) {
                Task {
                    await refreshSnapshot()
                }
            }
        }
    }

    var validationGuideSection: some View {
        Section("실기기 테스트 순서") {
            Text(
                "1. 장소 탭에서 실제 장소를 등록합니다."
            )

            Text(
                "2. 위치 권한이 Always인지 확인합니다."
            )

            Text(
                "3. Background Recognition을 켭니다."
            )

            Text(
                "4. 등록한 장소의 인식 반경 밖으로 충분히 이동합니다."
            )

            Text(
                "5. 앱을 백그라운드에 둔 상태로 다시 장소에 들어갑니다."
            )

            Text(
                "6. ARRIVED와 Active Visit이 생성되는지 확인합니다."
            )

            Text(
                "7. 실제로 장소에 머무른 뒤 다시 밖으로 이동합니다."
            )

            Text(
                "8. DEPARTED가 생성되는지 확인합니다."
            )

            Text(
                "9. 방문 기록 탭에서 입장·퇴장 시각과 체류시간을 확인합니다."
            )
        }
        .font(.subheadline)
    }
}

// MARK: - Actions

private extension DemoBackgroundValidationView {

    func refreshSnapshot() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        localErrorMessage = nil

        defer {
            isRefreshing = false
        }

        do {
            places =
                try await placeStore
                    .fetchAll()

            events =
                try await visitManager
                    .fetchEvents()

            currentNetwork =
                await environment
                    .wifiProvider
                    .currentNetwork()
        } catch {
            localErrorMessage =
                error.localizedDescription
        }
    }

    func synchronizeCandidates() async {
        localErrorMessage = nil

        do {
            try await visitManager
                .refreshBackgroundRecognition()

            await refreshSnapshot()
        } catch {
            localErrorMessage =
                error.localizedDescription
        }
    }
}

// MARK: - Presentation

private extension DemoBackgroundValidationView {

    var recentEvents: [PlaceVisitEvent] {
        Array(
            events
                .suffix(10)
                .reversed()
        )
    }

    var authorizationText: String {
        switch environment.authorizationStatus {
        case .notDetermined:
            return "미결정"

        case .restricted:
            return "제한됨"

        case .denied:
            return "거부됨"

        case .authorizedWhenInUse:
            return "앱 사용 중"

        case .authorizedAlways:
            return "Always"

        case .unknown:
            return "알 수 없음"
        }
    }

    func statusRow(
        title: String,
        value: String
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline
        ) {
            Text(title)

            Spacer(
                minLength: 12
            )

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    func placeName(
        for id: UUID
    ) -> String {
        places
            .first {
                $0.id == id
            }?
            .name
            .value
        ?? "삭제된 장소"
    }

    func eventText(
        _ kind: PlaceVisitEvent.Kind
    ) -> String {
        switch kind {
        case .arrived:
            return "ARRIVED"

        case .departed:
            return "DEPARTED"
        }
    }

    func formattedDate(
        _ date: Date
    ) -> String {
        date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    func currentDurationText(
        for visit: PlaceVisitRecord
    ) -> String {
        durationText(
            Date()
                .timeIntervalSince(
                    visit.startedAt
                )
        )
    }

    func durationText(
        _ interval: TimeInterval
    ) -> String {
        let totalSeconds =
            max(
                0,
                Int(interval)
            )

        if totalSeconds < 60 {
            return "< 1분"
        }

        let totalMinutes =
            totalSeconds / 60

        let hours =
            totalMinutes / 60

        let minutes =
            totalMinutes % 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }

        return "\(totalMinutes)분"
    }
}

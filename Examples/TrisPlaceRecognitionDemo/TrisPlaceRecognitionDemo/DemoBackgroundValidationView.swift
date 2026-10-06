//
//  DemoBackgroundValidationView.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-10-03.
//

import CoreLocation
import SwiftUI
import TrisLocationKit
import TrisPlaceRecognitionKit
import UIKit
import UserNotifications

@MainActor
struct DemoBackgroundValidationView: View {

    @Environment(\.scenePhase)
    private var scenePhase

    @ObservedObject
    private var environment:
        DemoEnvironment

    @ObservedObject
    private var visitManager:
        PlaceVisitManager

    private let placeStore:
        any PlaceStoring

    @State
    private var places:
        [RegisteredPlace] = []

    @State
    private var events:
        [PlaceVisitEvent] = []

    @State
    private var diagnosticEvents:
        [PlaceVisitDiagnosticEvent] = []

    @State
    private var systemMonitoredPlaceIDs:
        [UUID] = []

    @State
    private var currentNetwork:
        WiFiNetwork?

    @State
    private var isRefreshing =
        false

    @State
    private var localErrorMessage:
        String?

    private static let
        backgroundRegionIdentifierPrefix =
            "TrisPlaceRecognitionKit.background.place."

    @State
    private var exportedDiagnosticLog:
        ExportedDiagnosticLog?

    @State
    private var notificationAuthorizationStatus:
        UNAuthorizationStatus =
            .notDetermined

    init(
        environment:
            DemoEnvironment,
        placeStore:
            any PlaceStoring,
        visitManager:
            PlaceVisitManager
    ) {

        self.environment =
            environment

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

            List {

                authorizationSection

                notificationSection

                backgroundRecognitionSection

                systemMonitoringSection

                currentWiFiSection

                activeVisitSection

                recentEventSection

                diagnosticSection

                controlSection

                validationGuideSection

            }
            .navigationTitle(
                "실기기 검증"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .navigationBarTrailing
                ) {

                    Button {

                        Task {

                            await refreshSnapshot()
                        }

                    } label: {

                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }
                    .disabled(
                        isRefreshing
                    )
                }
            }
            .refreshable {

                await refreshSnapshot()
            }
        }
        .navigationViewStyle(
            .stack
        )
        .task {

            await refreshSnapshot()
        }
        .onChange(
            of: scenePhase
        ) { _, newPhase in

            guard
                newPhase == .active
            else {
                return
            }

            Task {

                await environment
                    .retryBackgroundRecognition()

                await refreshSnapshot()
            }
        }
        .sheet(
            item:
                $exportedDiagnosticLog
        ) { exportedLog in

            ActivityView(
                activityItems: [
                    exportedLog.url
                ]
            )
        }
    }
}

// MARK: - Sections

private extension DemoBackgroundValidationView {

    var notificationSection:
        some View {

        Section(
            "알림"
        ) {

            statusRow(
                title:
                    "알림 권한",
                value:
                    notificationAuthorizationText
            )

            Button(
                "알림 권한 요청"
            ) {

                Task {

                    await requestNotificationAuthorization()
                }
            }
            .disabled(
                notificationAuthorizationStatus
                    == .authorized
                    || notificationAuthorizationStatus
                        == .provisional
                    || notificationAuthorizationStatus
                        == .ephemeral
            )
        }
    }

    var authorizationSection:
        some View {

        Section(
            "위치 권한"
        ) {

            statusRow(
                title:
                    "현재 권한",
                value:
                    authorizationText
            )

            statusRow(
                title:
                    "Foreground Monitoring",
                value:
                    visitManager.isMonitoring
                    ? "실행 중"
                    : "중지"
            )

            statusRow(
                title:
                    "Background 요구 권한",
                value:
                    "Always"
            )
        }
    }

    var backgroundRecognitionSection:
        some View {

        Section(
            "Background Recognition"
        ) {

            statusRow(
                title:
                    "사용 설정",
                value:
                    environment
                        .wantsBackgroundRecognition
                    ? "ON"
                    : "OFF"
            )

            statusRow(
                title:
                    "Manager 상태",
                value:
                    visitManager
                        .isBackgroundRecognitionEnabled
                    ? "실행 중"
                    : "중지"
            )

            statusRow(
                title:
                    "등록 장소",
                value:
                    "\(places.count)개"
            )

            statusRow(
                title:
                    "Active Visit",
                value:
                    "\(visitManager.activeVisits.count)개"
            )

            statusRow(
                title:
                    "현재 인식 장소",
                value:
                    "\(visitManager.recognizedPlaces.count)개"
            )

            if let statusMessage =
                environment.statusMessage {

                Text(
                    statusMessage
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }

            if let error =
                visitManager
                    .lastBackgroundErrorMessage {

                Text(
                    error
                )
                .foregroundStyle(
                    .red
                )
            }

            if let localErrorMessage {

                Text(
                    localErrorMessage
                )
                .foregroundStyle(
                    .red
                )
            }
        }
    }

    var systemMonitoringSection:
        some View {

        Section(
            "System Monitored Regions"
        ) {

            statusRow(
                title:
                    "iOS 등록 Region",
                value:
                    "\(systemMonitoredPlaceIDs.count)개"
            )

            if systemMonitoredPlaceIDs
                .isEmpty {

                Text(
                    "TrisPlaceRecognitionKit이 등록한 region이 없습니다."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    systemMonitoredPlaceIDs,
                    id: \.self
                ) { placeID in

                    VStack(
                        alignment:
                            .leading,
                        spacing: 4
                    ) {

                        Text(
                            placeName(
                                for:
                                    placeID
                            )
                        )
                        .font(
                            .subheadline
                        )
                        .fontWeight(
                            .semibold
                        )

                        Text(
                            placeID
                                .uuidString
                        )
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .textSelection(
                            .enabled
                        )
                    }
                    .padding(
                        .vertical,
                        2
                    )
                }
            }
        }
    }

    var currentWiFiSection:
        some View {

        Section(
            "현재 Wi-Fi"
        ) {

            if let currentNetwork {

                statusRow(
                    title:
                        "SSID",
                    value:
                        currentNetwork
                            .ssid
                )

                statusRow(
                    title:
                        "BSSID",
                    value:
                        currentNetwork
                            .bssid
                        ?? "확인 불가"
                )

            } else {

                if places.allSatisfy({
                    $0.networkIdentities.isEmpty
                }) {

                    Text(
                        "현재 등록된 장소는 모두 GPS 전용입니다."
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        "Wi-Fi 정보는 조회하지 않습니다."
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                } else {

                    Text(
                        "현재 Wi-Fi 정보를 확인하지 못했습니다."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }
        }
    }

    var activeVisitSection:
        some View {

        Section(
            "현재 방문"
        ) {

            if visitManager
                .activeVisits
                .isEmpty {

                Text(
                    "현재 활성 방문 없음"
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    visitManager
                        .activeVisits,
                    id: \.id
                ) { visit in

                    VStack(
                        alignment:
                            .leading,
                        spacing: 6
                    ) {

                        Text(
                            placeName(
                                for:
                                    visit.placeID
                            )
                        )
                        .font(
                            .headline
                        )

                        Text(
                            "현재 위치한 장소"
                        )
                        .font(
                            .caption
                        )
                        .fontWeight(
                            .semibold
                        )

                        Text(
                            "입장 \(formattedDate(visit.startedAt))"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Text(
                            "현재 체류 \(currentDurationText(for: visit))"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
            }
        }
    }

    var recentEventSection:
        some View {

        Section(
            "최근 ARRIVED / DEPARTED"
        ) {

            if events.isEmpty {

                Text(
                    "아직 이벤트 없음"
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    recentEvents,
                    id: \.id
                ) { event in

                    VStack(
                        alignment:
                            .leading,
                        spacing: 6
                    ) {

                        HStack {

                            Text(
                                placeName(
                                    for:
                                        event.placeID
                                )
                            )
                            .font(
                                .headline
                            )

                            Spacer()

                            Text(
                                eventText(
                                    event.kind
                                )
                            )
                            .font(
                                .caption
                            )
                            .fontWeight(
                                .semibold
                            )
                        }

                        Text(
                            formattedDate(
                                event.occurredAt
                            )
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
            }
        }
    }

    var diagnosticSection:
        some View {

        Section(
            "최근 진단 로그"
        ) {

            if diagnosticEvents
                .isEmpty {

                Text(
                    "아직 진단 로그 없음"
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    recentDiagnosticEvents
                ) { event in

                    diagnosticEventRow(
                        event
                    )
                }
            }

            Button(
                "진단 로그 삭제",
                role:
                    .destructive
            ) {

                Task {

                    await clearDiagnosticEvents()
                }
            }
            .disabled(
                diagnosticEvents
                    .isEmpty
            )

            Button(
                "전체 진단 로그 내보내기"
            ) {

                Task {

                    await exportDiagnosticLog()
                }
            }
            .disabled(
                diagnosticEvents
                    .isEmpty
            )
        }
    }

    var controlSection:
        some View {

        Section(
            "제어"
        ) {

            if visitManager
                .isBackgroundRecognitionEnabled {

                Button(
                    "Background Recognition 끄기",
                    role:
                        .destructive
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

    var validationGuideSection:
        some View {

        Section(
            "실기기 테스트 순서"
        ) {

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
                "4. System Monitored Regions에 등록 장소가 나타나는지 확인합니다."
            )

            Text(
                "5. 진단 로그에 region.sync.succeeded가 기록됐는지 확인합니다."
            )

            Text(
                "6. 등록 장소의 인식 반경 밖으로 충분히 이동합니다."
            )

            Text(
                "7. 앱을 백그라운드에 둔 상태로 다시 장소에 들어갑니다."
            )

            Text(
                "8. region.entered → recognition.started → recognition.completed 순서를 확인합니다."
            )

            Text(
                "9. ARRIVED와 현재 위치한 장소 표시를 확인합니다."
            )

            Text(
                "10. 다시 장소 밖으로 나가 region.exited와 DEPARTED를 확인합니다."
            )
        }
        .font(
            .subheadline
        )
    }
}

// MARK: - Actions

private extension DemoBackgroundValidationView {

    func requestNotificationAuthorization()
        async {

        localErrorMessage =
            nil

        do {

            _ =
                try await UNUserNotificationCenter
                    .current()
                    .requestAuthorization(
                        options: [
                            .alert,
                            .sound
                        ]
                    )

            await refreshNotificationAuthorizationStatus()

        } catch {

            localErrorMessage =
                error.localizedDescription
        }
    }

    func refreshNotificationAuthorizationStatus()
        async {

        let settings =
            await UNUserNotificationCenter
                .current()
                .notificationSettings()

        notificationAuthorizationStatus =
            settings.authorizationStatus
    }

    func exportDiagnosticLog()
        async {

        localErrorMessage =
            nil

        do {

            let events =
                try await visitManager
                    .fetchDiagnosticEvents()

            guard
                !events.isEmpty
            else {

                localErrorMessage =
                    "내보낼 진단 로그가 없습니다."

                return
            }

            let encoder =
                JSONEncoder()

            encoder.dateEncodingStrategy =
                .iso8601

            encoder.outputFormatting = [
                .sortedKeys
            ]

            let lines =
                try events.map { event in

                    let data =
                        try encoder.encode(
                            event
                        )

                    guard
                        let line =
                            String(
                                data:
                                    data,
                                encoding:
                                    .utf8
                            )
                    else {

                        throw CocoaError(
                            .fileWriteInapplicableStringEncoding
                        )
                    }

                    return line
                }

            let text =
                lines.joined(
                    separator:
                        "\n"
                )
                + "\n"

            let formatter =
                DateFormatter()

            formatter.dateFormat =
                "yyyy-MM-dd_HH-mm-ss"

            let fileName =
                "place-visit-diagnostics-\(formatter.string(from: Date())).txt"

            let fileURL =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        fileName
                    )

            try Data(
                text.utf8
            )
            .write(
                to:
                    fileURL,
                options:
                    .atomic
            )

            exportedDiagnosticLog =
                ExportedDiagnosticLog(
                    url:
                        fileURL
                )

        } catch {

            localErrorMessage =
                error.localizedDescription
        }
    }

    func refreshSnapshot()
        async {

            guard
                !isRefreshing
            else {
                return
            }

            isRefreshing =
                true

            localErrorMessage =
                nil

            defer {

                isRefreshing =
                    false
            }

            await refreshNotificationAuthorizationStatus()

            do {

            places =
                try await placeStore
                    .fetchAll()

            events =
                try await visitManager
                    .fetchEvents()

            diagnosticEvents =
                try await visitManager
                    .fetchDiagnosticEvents()

            systemMonitoredPlaceIDs =
                loadSystemMonitoredPlaceIDs()

            let hasWiFiConfiguredPlace =
                places.contains {
                    !$0.networkIdentities
                        .isEmpty
                }

            if hasWiFiConfiguredPlace {

                currentNetwork =
                    await environment
                        .wifiProvider
                        .currentNetwork()

            } else {

                currentNetwork =
                    nil
            }

        } catch {

            localErrorMessage =
                error
                    .localizedDescription
        }
    }

    func synchronizeCandidates()
        async {

        localErrorMessage =
            nil

        do {

            try await visitManager
                .refreshBackgroundRecognition()

            await refreshSnapshot()

        } catch {

            localErrorMessage =
                error
                    .localizedDescription
        }
    }

    func clearDiagnosticEvents()
        async {

        localErrorMessage =
            nil

        do {

            try await visitManager
                .clearDiagnosticEvents()

            diagnosticEvents =
                []

        } catch {

            localErrorMessage =
                error
                    .localizedDescription
        }
    }

    func loadSystemMonitoredPlaceIDs()
        -> [UUID] {

        let manager =
            CLLocationManager()

        return manager
            .monitoredRegions
            .compactMap { region in

                Self.placeID(
                    from:
                        region.identifier
                )
            }
            .sorted {
                $0.uuidString
                    < $1.uuidString
            }
    }
}

// MARK: - Presentation

private extension DemoBackgroundValidationView {

    var notificationAuthorizationText:
        String {

        switch notificationAuthorizationStatus {

        case .notDetermined:

            return "미결정"

        case .denied:

            return "거부됨"

        case .authorized:

            return "허용됨"

        case .provisional:

            return "임시 허용"

        case .ephemeral:

            return "일시적 허용"

        @unknown default:

            return "알 수 없음"
        }
    }

    static func placeID(
        from identifier:
            String
    ) -> UUID? {

        guard
            identifier
                .hasPrefix(
                    backgroundRegionIdentifierPrefix
                )
        else {
            return nil
        }

        let value =
            String(
                identifier
                    .dropFirst(
                        backgroundRegionIdentifierPrefix
                            .count
                    )
            )

        return UUID(
            uuidString:
                value
        )
    }

    var recentEvents:
        [PlaceVisitEvent] {

        Array(
            events
                .suffix(
                    10
                )
                .reversed()
        )
    }

    var recentDiagnosticEvents:
        [PlaceVisitDiagnosticEvent] {

        Array(
            diagnosticEvents
                .suffix(
                    30
                )
                .reversed()
        )
    }

    var authorizationText:
        String {

        switch environment
            .authorizationStatus {

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
        title:
            String,
        value:
            String
    ) -> some View {

        HStack(
            alignment:
                .firstTextBaseline
        ) {

            Text(
                title
            )

            Spacer(
                minLength:
                    12
            )

            Text(
                value
            )
            .foregroundStyle(
                .secondary
            )
            .multilineTextAlignment(
                .trailing
            )
        }
    }

    func diagnosticEventRow(
        _ event:
            PlaceVisitDiagnosticEvent
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing: 6
        ) {

            HStack(
                alignment:
                    .firstTextBaseline
            ) {

                Text(
                    event.name
                )
                .font(
                    .caption
                )
                .fontWeight(
                    .semibold
                )

                Spacer()

                Text(
                    event.timestamp
                        .formatted(
                            date:
                                .omitted,
                            time:
                                .standard
                        )
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                event.category
                    .rawValue
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )

            if let placeID =
                event.placeID {

                Text(
                    "place: \(placeName(for: placeID))"
                )
                .font(
                    .caption2
                )
            }

            ForEach(
                event.metadata
                    .keys
                    .sorted(),
                id: \.self
            ) { key in

                Text(
                    "\(key): \(event.metadata[key] ?? "")"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
                .textSelection(
                    .enabled
                )
            }
        }
        .padding(
            .vertical,
            4
        )
    }

    func placeName(
        for id:
            UUID
    ) -> String {

        places
            .first {
                $0.id
                    == id
            }?
            .name
            .value
        ?? "삭제된 장소"
    }

    func eventText(
        _ kind:
            PlaceVisitEvent.Kind
    ) -> String {

        switch kind {

        case .arrived:

            return "ARRIVED"

        case .departed:

            return "DEPARTED"
        }
    }

    func formattedDate(
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

    func currentDurationText(
        for visit:
            PlaceVisitRecord
    ) -> String {

        durationText(
            Date()
                .timeIntervalSince(
                    visit.startedAt
                )
        )
    }

    func durationText(
        _ interval:
            TimeInterval
    ) -> String {

        let totalSeconds =
            max(
                0,
                Int(
                    interval
                )
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

            return
                "\(hours)시간 \(minutes)분"
        }

        return
            "\(totalMinutes)분"
    }

    private struct ExportedDiagnosticLog:
        Identifiable {

        let id =
            UUID()

        let url:
            URL
    }

    private struct ActivityView:
        UIViewControllerRepresentable {

        let activityItems:
            [Any]

        func makeUIViewController(
            context:
                Context
        ) -> UIActivityViewController {

            UIActivityViewController(
                activityItems:
                    activityItems,
                applicationActivities:
                    nil
            )
        }

        func updateUIViewController(
            _ uiViewController:
                UIActivityViewController,
            context:
                Context
        ) {
        }
    }
}

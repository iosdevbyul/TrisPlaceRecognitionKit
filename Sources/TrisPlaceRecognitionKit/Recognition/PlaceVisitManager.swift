//
//  PlaceVisitManager.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Combine
import Foundation
import TrisLocationKit

@MainActor
public final class PlaceVisitManager: ObservableObject {

    @Published
    public private(set)
    var recognizedPlaces: [RecognizedPlace] = []

    @Published
    public private(set)
    var activeVisits: [PlaceVisitRecord] = []

    @Published
    public private(set)
    var isMonitoring = false

    @Published
    public private(set)
    var isBackgroundRecognitionEnabled = false

    @Published
    public private(set)
    var lastErrorMessage: String?

    @Published
    public private(set)
    var lastVisitErrorMessage: String?

    @Published
    public private(set)
    var lastBackgroundErrorMessage: String?

    private let recognitionService:
        PlaceRecognitionService

    private let monitor:
        PlaceRecognitionMonitor

    private let coordinator:
        PlaceVisitCoordinator

    private let visitStore:
        any PlaceVisitStoring

    private let backgroundRecognitionPolicy:
        BackgroundRecognitionPolicy

    private let backgroundMonitoringService:
        BackgroundRegionMonitoringService

    private let backgroundEventProcessor:
        BackgroundRecognitionEventProcessor

    private let diagnosticStore:
        any PlaceVisitDiagnosticStoring

    private let visitNotifier:
        any PlaceVisitNotifying

    private var backgroundEventTask:
        Task<Void, Never>?

    private var restorationTask:
        Task<[PlaceVisitRecord], Error>?

    private var hasRestoredVisits = false

    // MARK: - Init

    public convenience init(
        recognitionService:
            PlaceRecognitionService,
        visitStore:
            any PlaceVisitStoring,
        recognitionPolicy:
            PlaceRecognitionPolicy = .wifiOrGPS,
        visitPolicy:
            PlaceVisitPolicy = .init(),
        refreshInterval:
            TimeInterval = 15,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy = .init(),
        placeVisitNotificationsEnabled:
            Bool = false
    ) {
        let visitNotifier:
            any PlaceVisitNotifying

        if placeVisitNotificationsEnabled {

            visitNotifier =
                UserNotificationPlaceVisitNotifier()

        } else {

            visitNotifier =
                NoOpPlaceVisitNotifier()
        }

        self.init(
            recognitionService:
                recognitionService,
            visitStore:
                visitStore,
            recognitionPolicy:
                recognitionPolicy,
            visitPolicy:
                visitPolicy,
            refreshInterval:
                refreshInterval,
            backgroundRecognitionPolicy:
                backgroundRecognitionPolicy,
            backgroundMonitor:
                CoreLocationBackgroundRegionMonitor(),
            diagnosticStore:
                FilePlaceVisitDiagnosticLogger(),
            visitNotifier:
                visitNotifier
        )
    }

    init(
        recognitionService: PlaceRecognitionService,
        visitStore: any PlaceVisitStoring,
        recognitionPolicy: PlaceRecognitionPolicy,
        visitPolicy: PlaceVisitPolicy,
        refreshInterval: TimeInterval,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy,
        backgroundMonitor:
            any BackgroundRegionMonitoring,
        diagnosticStore:
            any PlaceVisitDiagnosticStoring =
                NoOpPlaceVisitDiagnosticStore(),
        visitNotifier:
            any PlaceVisitNotifying =
                NoOpPlaceVisitNotifier()
    ) {

        let diagnosticVisitStore =
            DiagnosticPlaceVisitStore(
                base:
                    visitStore,
                diagnosticStore:
                    diagnosticStore
            )

        let coordinator =
            PlaceVisitCoordinator(
                store:
                    diagnosticVisitStore,
                policy:
                    visitPolicy
            )

        let monitor =
            PlaceRecognitionMonitor(
                recognitionService:
                    recognitionService,
                policy:
                    recognitionPolicy,
                refreshInterval:
                    refreshInterval
            )

        self.recognitionService =
            recognitionService

        self.visitStore =
            diagnosticVisitStore

        self.coordinator =
            coordinator

        self.monitor =
            monitor

        self.backgroundRecognitionPolicy =
            backgroundRecognitionPolicy

        self.backgroundMonitoringService =
            BackgroundRegionMonitoringService(
                monitor:
                    backgroundMonitor
            )

        self.backgroundEventProcessor =
            BackgroundRecognitionEventProcessor(
                recognitionService:
                    recognitionService,
                coordinator:
                    coordinator,
                recognitionPolicy:
                    recognitionPolicy
            )

        self.diagnosticStore =
            diagnosticStore

        self.visitNotifier =
            visitNotifier

        bindMonitor()

        monitor.onSuccessfulRecognition = {
            [weak self] places, observedAt in

            guard let self else {
                return
            }

            try await self
                .processSuccessfulObservation(
                    places,
                    at:
                        observedAt
                )
        }
    }

    @available(iOS 17.0, *)
    public convenience init(
        recognitionService:
            PlaceRecognitionService,
        recognitionPolicy:
            PlaceRecognitionPolicy = .wifiOrGPS,
        visitPolicy:
            PlaceVisitPolicy = .init(),
        refreshInterval:
            TimeInterval = 15,
        backgroundRecognitionPolicy:
            BackgroundRecognitionPolicy = .init(),
        placeVisitNotificationsEnabled:
            Bool = false
    ) throws {
        let visitNotifier:
            any PlaceVisitNotifying

        if placeVisitNotificationsEnabled {

            visitNotifier =
                UserNotificationPlaceVisitNotifier()

        } else {

            visitNotifier =
                NoOpPlaceVisitNotifier()
        }

        let visitStore =
            try SwiftDataPlaceVisitStore()

        self.init(
            recognitionService:
                recognitionService,
            visitStore:
                visitStore,
            recognitionPolicy:
                recognitionPolicy,
            visitPolicy:
                visitPolicy,
            refreshInterval:
                refreshInterval,
            backgroundRecognitionPolicy:
                backgroundRecognitionPolicy,
            backgroundMonitor:
                CoreLocationBackgroundRegionMonitor(),
            diagnosticStore:
                FilePlaceVisitDiagnosticLogger(),
            visitNotifier: visitNotifier
        )
    }

    // MARK: - Foreground Monitoring

    @discardableResult
    public func restore()
        async throws
        -> [PlaceVisitRecord] {

        try await restoreIfNeeded()

        return activeVisits
    }

    public func start()
        async throws {

        try await restoreIfNeeded()

        await monitor.start()
    }

    public func refresh()
        async throws {

        try await restoreIfNeeded()

        if isMonitoring {
            await monitor.refresh()
        } else {
            await monitor.start()
        }
    }

    public func stop() {

        monitor.stop()
    }

    // MARK: - Background Recognition

    /// Starts low-power background place recognition.
    ///
    /// This does not start continuous location updates.
    /// A single location snapshot is requested only when
    /// the monitored place set must be calculated.
    public func startBackgroundRecognition()
        async throws {

        await recordDiagnostic(
            category:
                .lifecycle,
            name:
                "background.start.requested"
        )

        do {

            try await restoreIfNeeded()

            if isBackgroundRecognitionEnabled {

                try await refreshBackgroundRecognition()

                await recordDiagnostic(
                    category:
                        .lifecycle,
                    name:
                        "background.start.succeeded"
                )

                return
            }

            try await synchronizeBackgroundMonitoring()

            isBackgroundRecognitionEnabled =
                true

            lastBackgroundErrorMessage =
                nil

            startBackgroundEventListening()

            await recordDiagnostic(
                category:
                    .lifecycle,
                name:
                    "background.start.succeeded"
            )

        } catch {

            lastBackgroundErrorMessage =
                error.localizedDescription

            await recordDiagnostic(
                category:
                    .error,
                name:
                    "background.start.failed",
                metadata: [
                    "error":
                        error.localizedDescription
                ]
            )

            throw error
        }
    }

    /// Recalculates which registered places should be
    /// monitored by the system.
    ///
    /// No work is performed when background recognition
    /// has not been enabled.
    public func refreshBackgroundRecognition()
        async throws {

        guard
            isBackgroundRecognitionEnabled
        else {
            return
        }

        await recordDiagnostic(
            category:
                .lifecycle,
            name:
                "background.refresh.requested"
        )

        do {

            try await synchronizeBackgroundMonitoring()

            lastBackgroundErrorMessage =
                nil

            await recordDiagnostic(
                category:
                    .lifecycle,
                name:
                    "background.refresh.succeeded"
            )

        } catch {

            lastBackgroundErrorMessage =
                error.localizedDescription

            await recordDiagnostic(
                category:
                    .error,
                name:
                    "background.refresh.failed",
                metadata: [
                    "error":
                        error.localizedDescription
                ]
            )

            if !isBackgroundRecognitionEnabled {

                backgroundEventTask?
                    .cancel()

                backgroundEventTask =
                    nil
            }

            throw error
        }
    }

    /// Stops only background place recognition.
    ///
    /// Foreground recognition is controlled separately
    /// through start(), refresh(), and stop().
    public func stopBackgroundRecognition()
        async {

        await recordDiagnostic(
            category:
                .lifecycle,
            name:
                "background.stop.requested"
        )

        backgroundEventTask?
            .cancel()

        backgroundEventTask =
            nil

        await backgroundMonitoringService
            .stop()

        isBackgroundRecognitionEnabled =
            false

        lastBackgroundErrorMessage =
            nil

        await recordDiagnostic(
            category:
                .lifecycle,
            name:
                "background.stop.succeeded"
        )
    }

    // MARK: - Diagnostics

    public func fetchDiagnosticEvents()
        async throws
        -> [PlaceVisitDiagnosticEvent] {

        try await diagnosticStore
            .fetchAll()
    }

    public func clearDiagnosticEvents()
        async throws {

        try await diagnosticStore
            .clear()
    }

    // MARK: - Visit Queries

    public func fetchVisits()
        async throws
        -> [PlaceVisitRecord] {

        let visits =
            try await visitStore
                .fetchAll()

        return sortedVisits(
            visits
        )
    }

    public func fetchVisits(
        for placeID: UUID
    ) async throws
        -> [PlaceVisitRecord] {

        let visits =
            try await visitStore
                .fetchAll()

        return sortedVisits(
            visits.filter {
                $0.placeID
                    == placeID
            }
        )
    }

    public func fetchVisits(
        from startDate: Date,
        to endDate: Date
    ) async throws
        -> [PlaceVisitRecord] {

        try validateDateRange(
            from:
                startDate,
            to:
                endDate
        )

        let visits =
            try await visitStore
                .fetchAll()

        return sortedVisits(
            visits.filter {

                overlaps(
                    $0,
                    startDate:
                        startDate,
                    endDate:
                        endDate
                )
            }
        )
    }

    public func fetchVisits(
        for placeID: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws
        -> [PlaceVisitRecord] {

        try validateDateRange(
            from:
                startDate,
            to:
                endDate
        )

        let visits =
            try await visitStore
                .fetchAll()

        return sortedVisits(
            visits.filter {

                $0.placeID
                    == placeID
                    && overlaps(
                        $0,
                        startDate:
                            startDate,
                        endDate:
                            endDate
                    )
            }
        )
    }

    public func fetchLatestVisit(
        for placeID: UUID
    ) async throws
        -> PlaceVisitRecord? {

        let visits =
            try await visitStore
                .fetchAll()

        return visits
            .filter {
                $0.placeID
                    == placeID
            }
            .max { lhs, rhs in

                if lhs.startedAt
                    != rhs.startedAt {

                    return lhs.startedAt
                        < rhs.startedAt
                }

                return lhs.id.uuidString
                    < rhs.id.uuidString
            }
    }

    public func fetchEvents()
        async throws
        -> [PlaceVisitEvent] {

        let events =
            try await visitStore
                .fetchEvents()

        return events.sorted {
            lhs,
            rhs in

            if lhs.occurredAt
                != rhs.occurredAt {

                return lhs.occurredAt
                    < rhs.occurredAt
            }

            return lhs.id.uuidString
                < rhs.id.uuidString
        }
    }
}

// MARK: - Private

private extension PlaceVisitManager {

    func bindMonitor() {

        monitor
            .$recognizedPlaces
            .assign(
                to:
                    &$recognizedPlaces
            )

        monitor
            .$isMonitoring
            .assign(
                to:
                    &$isMonitoring
            )

        monitor
            .$lastErrorMessage
            .assign(
                to:
                    &$lastErrorMessage
            )

        monitor
            .$lastVisitErrorMessage
            .assign(
                to:
                    &$lastVisitErrorMessage
            )
    }

    func restoreIfNeeded()
        async throws {

        if hasRestoredVisits {
            return
        }

        if let restorationTask {

            let restored =
                try await restorationTask
                    .value

            activeVisits =
                restored

            hasRestoredVisits =
                true

            return
        }

        let coordinator =
            self.coordinator

        let task =
            Task {

                try await coordinator
                    .restore()
            }

        restorationTask =
            task

        do {

            let restored =
                try await task
                    .value

            activeVisits =
                restored

            hasRestoredVisits =
                true

            restorationTask =
                nil

        } catch {

            restorationTask =
                nil

            throw error
        }
    }

    func processSuccessfulObservation(
        _ places:
            [RecognizedPlace],
        at timestamp:
            Date
    ) async throws {

        let update =
            try await coordinator
                .processSuccessfulObservation(
                    places,
                    at:
                        timestamp
                )

        activeVisits =
            try await coordinator
                .activeVisits()

        await notifyVisitEvents(
            update.events
        )
    }

    // MARK: - Background Synchronization

    func synchronizeBackgroundMonitoring()
        async throws {

        let places =
            try await recognitionService
                .fetchRegisteredPlacesForBackgroundMonitoring()

        await recordDiagnostic(
            category:
                .regionSync,
            name:
                "region.sync.registeredPlaces",
            metadata: [
                "count":
                    "\(places.count)"
            ]
        )

        guard
            !places.isEmpty
        else {

            await backgroundMonitoringService
                .stop()

            await recordDiagnostic(
                category:
                    .regionSync,
                name:
                    "region.sync.empty"
            )

            return
        }

        await recordDiagnostic(
            category:
                .authorization,
            name:
                "authorization.background",
            metadata: [
                "status":
                    String(
                        describing:
                            recognitionService
                                .locationAuthorizationStatus
                    )
            ]
        )

        do {

            try validateBackgroundAuthorization()

        } catch {

            isBackgroundRecognitionEnabled =
                false

            await backgroundMonitoringService
                .stop()

            await recordDiagnostic(
                category:
                    .error,
                name:
                    "authorization.background.failed",
                metadata: [
                    "error":
                        error.localizedDescription
                ]
            )

            throw error
        }

            let candidates: [BackgroundMonitoringCandidate]

            if places.count
                <= backgroundRecognitionPolicy
                    .maximumMonitoredPlaces {

                candidates =
                    places.compactMap { place in
                        guard place.location != nil else {
                            return nil
                        }

                        return BackgroundMonitoringCandidate(
                            place:
                                place,
                            distanceMeters:
                                0
                        )
                    }

                await recordDiagnostic(
                    category:
                        .regionSync,
                    name:
                        "region.sync.locationSnapshotSkipped",
                    metadata: [
                        "reason":
                            "allPlacesFit",
                        "registeredCount":
                            "\(places.count)",
                        "maximumMonitoredPlaces":
                            "\(backgroundRecognitionPolicy.maximumMonitoredPlaces)"
                    ]
                )

            } else {

                guard
                    let currentLocation =
                        try await recognitionService
                            .requestBackgroundMonitoringLocation()
                else {

                    await recordDiagnostic(
                        category:
                            .error,
                        name:
                            "region.sync.locationSnapshotRejected"
                    )

                    throw BackgroundRecognitionManagerError
                        .unacceptableLocationSnapshot
                }

                await recordDiagnostic(
                    category:
                        .regionSync,
                    name:
                        "region.sync.locationSnapshot",
                    metadata: [
                        "horizontalAccuracy":
                            String(
                                format:
                                    "%.1f",
                                currentLocation
                                    .horizontalAccuracy
                            )
                    ]
                )

                let prioritizedPlaceIDs =
                    Set(
                        activeVisits.map(
                            \.placeID
                        )
                    )

                candidates =
                    BackgroundMonitoringCandidateSelector
                        .select(
                            from:
                                places,
                            currentLatitude:
                                currentLocation
                                    .latitude,
                            currentLongitude:
                                currentLocation
                                    .longitude,
                            prioritizedPlaceIDs:
                                prioritizedPlaceIDs,
                            policy:
                                backgroundRecognitionPolicy
                        )
            }

        await recordDiagnostic(
            category:
                .regionSync,
            name:
                "region.sync.candidates",
            metadata: [
                "registeredCount":
                    "\(places.count)",
                "candidateCount":
                    "\(candidates.count)",
                "candidatePlaceIDs":
                    candidates
                        .map {
                            $0.place.id
                                .uuidString
                        }
                        .joined(
                            separator:
                                ","
                        )
            ]
        )

        let requiresCandidateRefresh =
            places.count
                > candidates.count
                || !activeVisits.isEmpty

        do {

            try await backgroundMonitoringService
                .synchronize(
                    candidates:
                        candidates,
                    requiresCandidateRefresh:
                        requiresCandidateRefresh
                )

            await recordDiagnostic(
                category:
                    .regionSync,
                name:
                    "region.sync.succeeded",
                metadata: [
                    "candidateCount":
                        "\(candidates.count)",
                    "candidateRefresh":
                        "\(requiresCandidateRefresh)"
                ]
            )

        } catch {

            isBackgroundRecognitionEnabled =
                false

            await recordDiagnostic(
                category:
                    .error,
                name:
                    "region.sync.failed",
                metadata: [
                    "error":
                        error.localizedDescription
                ]
            )

            throw error
        }
    }

    func validateBackgroundAuthorization()
        throws {

        switch recognitionService
            .locationAuthorizationStatus {

        case .authorizedAlways:

            return

        case .notDetermined,
             .authorizedWhenInUse:

            recognitionService
                .requestAlwaysLocationAuthorization()

            throw BackgroundRecognitionManagerError
                .alwaysAuthorizationRequired

        case .denied:

            throw BackgroundRecognitionManagerError
                .authorizationDenied

        case .restricted:

            throw BackgroundRecognitionManagerError
                .authorizationRestricted

        case .unknown:

            throw BackgroundRecognitionManagerError
                .authorizationUnknown
        }
    }

    // MARK: - Background Event Listening

    func startBackgroundEventListening() {

        backgroundEventTask?
            .cancel()

        let events =
            backgroundMonitoringService
                .events()

        backgroundEventTask =
            Task {
                [weak self] in

                do {

                    for try await trigger
                        in events {

                        guard
                            !Task.isCancelled
                        else {
                            return
                        }

                        guard
                            let self
                        else {
                            return
                        }

                        await self
                            .recordDiagnostic(
                                category:
                                    .regionEvent,
                                name:
                                    self
                                        .diagnosticName(
                                            for:
                                                trigger
                                        ),
                                placeID:
                                    self
                                        .placeID(
                                            for:
                                                trigger
                                        )
                            )

                        do {

                            try await self
                                .processBackgroundTrigger(
                                    trigger
                                )

                            self
                                .lastBackgroundErrorMessage =
                                nil

                        } catch is CancellationError {

                            return

                        } catch {

                            self
                                .lastBackgroundErrorMessage =
                                error
                                    .localizedDescription

                            await self
                                .recordDiagnostic(
                                    category:
                                        .error,
                                    name:
                                        "background.trigger.failed",
                                    placeID:
                                        self
                                            .placeID(
                                                for:
                                                    trigger
                                            ),
                                    metadata: [
                                        "error":
                                            error
                                                .localizedDescription
                                    ]
                                )

                            if !self
                                .isBackgroundRecognitionEnabled {

                                self.backgroundEventTask =
                                    nil

                                return
                            }
                        }
                    }

                    guard
                        !Task.isCancelled,
                        let self
                    else {
                        return
                    }

                    guard self
                        .isBackgroundRecognitionEnabled
                    else {

                        self.backgroundEventTask =
                            nil

                        return
                    }

                    await self
                        .recordDiagnostic(
                            category:
                                .error,
                            name:
                                "background.eventStream.finished"
                        )

                    self
                        .isBackgroundRecognitionEnabled =
                        false

                    await self
                        .backgroundMonitoringService
                        .stop()

                    self.backgroundEventTask =
                        nil

                } catch is CancellationError {

                    return

                } catch {

                    guard
                        !Task.isCancelled,
                        let self
                    else {
                        return
                    }

                    self
                        .lastBackgroundErrorMessage =
                        error
                            .localizedDescription

                    await self
                        .recordDiagnostic(
                            category:
                                .error,
                            name:
                                "background.eventStream.failed",
                            metadata: [
                                "error":
                                    error
                                        .localizedDescription
                            ]
                        )

                    await self
                        .backgroundMonitoringService
                        .stop()

                    self
                        .isBackgroundRecognitionEnabled =
                        false

                    self.backgroundEventTask =
                        nil
                }
            }
    }

    func processBackgroundTrigger(
        _ trigger:
            BackgroundRecognitionTrigger
    ) async throws {

        switch trigger {

        case .significantLocationChange:

            await recordDiagnostic(
                category:
                    .regionEvent,
                name:
                    "location.significantChange"
            )

            if !activeVisits.isEmpty {

                await recordDiagnostic(
                    category:
                        .recognition,
                    name:
                        "recognition.started"
                )

                let result =
                    try await backgroundEventProcessor
                        .handle(
                            trigger
                        )

                await recordDiagnostic(
                    category:
                        .recognition,
                    name:
                        "recognition.completed",
                    metadata: [
                        "recognizedCount":
                            "\(result.recognizedPlaces.count)",
                        "recognizedPlaceIDs":
                            result
                                .recognizedPlaces
                                .map {
                                    $0.place.id
                                        .uuidString
                                }
                                .joined(
                                    separator:
                                        ","
                                )
                    ]
                )

                await recordDiagnostic(
                    category:
                        .visit,
                    name:
                        "visit.update",
                    metadata: [
                        "events":
                            "\(result.visitUpdate.events.count)",
                        "startedVisits":
                            "\(result.visitUpdate.startedVisits.count)",
                        "endedVisits":
                            "\(result.visitUpdate.endedVisits.count)"
                    ]
                )

                activeVisits =
                    try await coordinator
                        .activeVisits()

                await notifyVisitEvents(
                    result.visitUpdate.events
                )
            }

            try await synchronizeBackgroundMonitoring()

        case .monitoredRegionEntered,
             .monitoredRegionExited:

            let triggerPlaceID =
                placeID(
                    for:
                        trigger
                )

            await recordDiagnostic(
                category:
                    .recognition,
                name:
                    "recognition.started",
                placeID:
                    triggerPlaceID
            )

            let result =
                try await backgroundEventProcessor
                    .handle(
                        trigger
                    )

            await recordDiagnostic(
                category:
                    .recognition,
                name:
                    "recognition.completed",
                placeID:
                    triggerPlaceID,
                metadata: [
                    "recognizedCount":
                        "\(result.recognizedPlaces.count)",
                    "recognizedPlaceIDs":
                        result
                            .recognizedPlaces
                            .map {
                                $0.place.id
                                    .uuidString
                            }
                            .joined(
                                separator:
                                    ","
                            )
                ]
            )

            await recordDiagnostic(
                category:
                    .visit,
                name:
                    "visit.update",
                placeID:
                    triggerPlaceID,
                metadata: [
                    "events":
                        "\(result.visitUpdate.events.count)",
                    "startedVisits":
                        "\(result.visitUpdate.startedVisits.count)",
                    "endedVisits":
                        "\(result.visitUpdate.endedVisits.count)"
                ]
            )

            activeVisits =
                try await coordinator
                    .activeVisits()

            await notifyVisitEvents(
                result.visitUpdate.events
            )
        }
    }

    // MARK: - Diagnostics

    func recordDiagnostic(
        category:
            PlaceVisitDiagnosticCategory,
        name: String,
        placeID: UUID? = nil,
        metadata:
            [String: String] = [:]
    ) async {

        do {

            try await diagnosticStore
                .append(
                    PlaceVisitDiagnosticEvent(
                        category:
                            category,
                        name:
                            name,
                        placeID:
                            placeID,
                        metadata:
                            metadata
                    )
                )

        } catch {

            // Diagnostic persistence must never break
            // recognition or visit processing.
        }
    }

    func diagnosticName(
        for trigger:
            BackgroundRecognitionTrigger
    ) -> String {

        switch trigger {

        case .monitoredRegionEntered:

            return "region.entered"

        case .monitoredRegionExited:

            return "region.exited"

        case .significantLocationChange:

            return "location.significantChange"
        }
    }

    func placeID(
        for trigger:
            BackgroundRecognitionTrigger
    ) -> UUID? {

        switch trigger {

        case .monitoredRegionEntered(
            let placeID
        ),
        .monitoredRegionExited(
            let placeID
        ):

            return placeID

        case .significantLocationChange:

            return nil
        }
    }

    // MARK: - Queries

    func validateDateRange(
        from startDate: Date,
        to endDate: Date
    ) throws {

        guard
            startDate
                .timeIntervalSince1970
                .isFinite,
            endDate
                .timeIntervalSince1970
                .isFinite,
            startDate
                <= endDate
        else {

            throw PlaceVisitQueryError
                .invalidDateRange
        }
    }

    func overlaps(
        _ visit:
            PlaceVisitRecord,
        startDate:
            Date,
        endDate:
            Date
    ) -> Bool {

        guard
            visit.startedAt
                <= endDate
        else {
            return false
        }

        guard
            let visitEnd =
                visit.endedAt
        else {

            return true
        }

        return visitEnd
            >= startDate
    }

    func sortedVisits(
        _ visits:
            [PlaceVisitRecord]
    ) -> [PlaceVisitRecord] {

        visits.sorted {
            lhs,
            rhs in

            if lhs.startedAt
                != rhs.startedAt {

                return lhs.startedAt
                    < rhs.startedAt
            }

            return lhs.id.uuidString
                < rhs.id.uuidString
        }
    }

    func notifyVisitEvents(
        _ events:
            [PlaceVisitEvent]
    ) async {

        guard !events.isEmpty else {
            return
        }

        do {

            let registeredPlaces =
                try await recognitionService
                    .fetchRegisteredPlacesForBackgroundMonitoring()

            let placeNamesByID =
                Dictionary(
                    uniqueKeysWithValues:
                        registeredPlaces.map {
                            (
                                $0.id,
                                $0.name.value
                            )
                        }
                )

            for event in events {

                guard
                    let placeName =
                        placeNamesByID[
                            event.placeID
                        ]
                else {
                    continue
                }

                do {

                    switch event.kind {

                    case .arrived:

                        try await visitNotifier
                            .notifyArrival(
                                placeName:
                                    placeName
                            )

                    case .departed:

                        try await visitNotifier
                            .notifyDeparture(
                                placeName:
                                    placeName
                            )
                    }

                } catch {

                    await recordDiagnostic(
                        category:
                            .error,
                        name:
                            "notification.visit.failed",
                        placeID:
                            event.placeID,
                        metadata: [
                            "kind":
                                event.kind.rawValue,
                            "error":
                                error.localizedDescription
                        ]
                    )
                }
            }

        } catch {

            await recordDiagnostic(
                category:
                    .error,
                name:
                    "notification.placeLookup.failed",
                metadata: [
                    "error":
                        error.localizedDescription
                ]
            )
        }
    }
}

//
//  BackgroundRegionMonitoringService.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

@MainActor
final class BackgroundRegionMonitoringService {

    private let monitor:
        any BackgroundRegionMonitoring

    init(
        monitor: any BackgroundRegionMonitoring
    ) {
        self.monitor = monitor
    }

    func synchronize(
        candidates: [BackgroundMonitoringCandidate],
        requiresCandidateRefresh: Bool
    ) async throws {

        guard !candidates.isEmpty else {

            await monitor.stopAll()

            return
        }

        let regions =
            candidates.map {

                BackgroundMonitoredRegion(
                    candidate: $0
                )
            }

        do {

            try await monitor.synchronize(
                regions: regions
            )

            try await monitor
                .setCandidateRefreshMonitoringEnabled(
                    requiresCandidateRefresh
                )

        } catch {

            // Do not leave partially configured
            // background monitoring running.
            await monitor.stopAll()

            throw error
        }
    }

    func events()
        -> AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        > {

        monitor.events()
    }

    func stop() async {

        await monitor.stopAll()
    }
}

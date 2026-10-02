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
        candidates: [BackgroundMonitoringCandidate]
    ) async throws {

        guard !candidates.isEmpty else {
            await monitor.stopAll()
            return
        }

        let regions = candidates.map {
            BackgroundMonitoredRegion(
                candidate: $0
            )
        }

        try await monitor.synchronize(
            regions: regions
        )
    }

    func events()
        -> AsyncStream<BackgroundRecognitionTrigger> {

        monitor.events()
    }

    func stop() async {
        await monitor.stopAll()
    }
}

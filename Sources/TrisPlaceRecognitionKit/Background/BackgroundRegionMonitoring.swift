//
//  BackgroundRegionMonitoring.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

@MainActor
protocol BackgroundRegionMonitoring:
    AnyObject {

    func events()
        -> AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        >

    func synchronize(
        regions: [BackgroundMonitoredRegion]
    ) async throws

    func setCandidateRefreshMonitoringEnabled(
        _ enabled: Bool
    ) async throws

    func stopAll() async
}

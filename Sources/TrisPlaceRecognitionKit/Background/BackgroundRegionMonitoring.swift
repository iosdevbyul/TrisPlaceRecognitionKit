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
        -> AsyncStream<BackgroundRecognitionTrigger>

    func synchronize(
        regions: [BackgroundMonitoredRegion]
    ) async throws

    func stopAll() async
}

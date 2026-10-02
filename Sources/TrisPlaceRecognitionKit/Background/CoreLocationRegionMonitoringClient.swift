//
//  CoreLocationRegionMonitoringClient.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
@preconcurrency import CoreLocation

@MainActor
protocol CoreLocationRegionMonitoringClient:
    AnyObject {

    var monitoredRegions: [CLRegion] {
        get
    }

    var maximumRegionMonitoringDistance:
        CLLocationDistance {
        get
    }

    var isCircularRegionMonitoringAvailable:
        Bool {
        get
    }

    var onRegionEntered:
        ((CLRegion) -> Void)? {
        get set
    }

    var onRegionExited:
        ((CLRegion) -> Void)? {
        get set
    }

    var onMonitoringFailure:
        ((CLRegion?, any Error) -> Void)? {
        get set
    }

    func startMonitoring(
        for region: CLRegion
    )

    func stopMonitoring(
        for region: CLRegion
    )
}

@MainActor
final class SystemCoreLocationRegionMonitoringClient:
    NSObject,
    CoreLocationRegionMonitoringClient {

    private let locationManager:
        CLLocationManager

    var onRegionEntered:
        ((CLRegion) -> Void)?

    var onRegionExited:
        ((CLRegion) -> Void)?

    var onMonitoringFailure:
        ((CLRegion?, any Error) -> Void)?

    override init() {
        locationManager = CLLocationManager()

        super.init()

        locationManager.delegate = self
    }

    var monitoredRegions: [CLRegion] {
        Array(
            locationManager.monitoredRegions
        )
    }

    var maximumRegionMonitoringDistance:
        CLLocationDistance {

        locationManager
            .maximumRegionMonitoringDistance
    }

    var isCircularRegionMonitoringAvailable:
        Bool {

        CLLocationManager.isMonitoringAvailable(
            for: CLCircularRegion.self
        )
    }

    func startMonitoring(
        for region: CLRegion
    ) {
        locationManager.startMonitoring(
            for: region
        )
    }

    func stopMonitoring(
        for region: CLRegion
    ) {
        locationManager.stopMonitoring(
            for: region
        )
    }
}

extension SystemCoreLocationRegionMonitoringClient:
    @MainActor CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didEnterRegion region: CLRegion
    ) {
        onRegionEntered?(region)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didExitRegion region: CLRegion
    ) {
        onRegionExited?(region)
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: any Error
    ) {
        onMonitoringFailure?(
            region,
            error
        )
    }
}

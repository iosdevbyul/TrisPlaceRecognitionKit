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

    var isSignificantLocationChangeMonitoringAvailable:
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

    var onSignificantLocationChanged:
        (() -> Void)? {
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

    func startMonitoringSignificantLocationChanges()

    func stopMonitoringSignificantLocationChanges()
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

    var onSignificantLocationChanged:
        (() -> Void)?

    var onMonitoringFailure:
        ((CLRegion?, any Error) -> Void)?

    override init() {

        locationManager =
            CLLocationManager()

        super.init()

        locationManager.delegate =
            self
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

        CLLocationManager
            .isMonitoringAvailable(
                for: CLCircularRegion.self
            )
    }

    var isSignificantLocationChangeMonitoringAvailable:
        Bool {

        CLLocationManager
            .significantLocationChangeMonitoringAvailable()
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

    func startMonitoringSignificantLocationChanges() {

        locationManager
            .startMonitoringSignificantLocationChanges()
    }

    func stopMonitoringSignificantLocationChanges() {

        locationManager
            .stopMonitoringSignificantLocationChanges()
    }
}

extension SystemCoreLocationRegionMonitoringClient:
    @MainActor CLLocationManagerDelegate {

    func locationManager(
        _ manager: CLLocationManager,
        didEnterRegion region: CLRegion
    ) {

        onRegionEntered?(
            region
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didExitRegion region: CLRegion
    ) {

        onRegionExited?(
            region
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard !locations.isEmpty else {
            return
        }

        // This CLLocationManager is intentionally used
        // only for region monitoring and the low-power
        // significant-change service.
        //
        // Coordinates aren't retained here because this
        // callback is only a trigger to recalculate nearby
        // monitoring candidates.
        onSignificantLocationChanged?()
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

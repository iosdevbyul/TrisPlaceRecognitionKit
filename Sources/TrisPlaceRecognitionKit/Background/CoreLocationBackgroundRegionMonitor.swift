//
//  CoreLocationBackgroundRegionMonitor.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation
@preconcurrency import CoreLocation

@MainActor
final class CoreLocationBackgroundRegionMonitor:
    BackgroundRegionMonitoring {

    static let identifierPrefix =
        "TrisPlaceRecognitionKit.background.place."

    private let client:
        any CoreLocationRegionMonitoringClient

    private var eventContinuations: [
        UUID:
            AsyncThrowingStream<
                BackgroundRecognitionTrigger,
                Error
            >.Continuation
    ] = [:]

    init() {
        client =
            SystemCoreLocationRegionMonitoringClient()

        bindClient()
    }

    init(
        client:
            any CoreLocationRegionMonitoringClient
    ) {
        self.client = client

        bindClient()
    }

    func events()
        -> AsyncThrowingStream<
            BackgroundRecognitionTrigger,
            Error
        > {

        AsyncThrowingStream { continuation in

            let id = UUID()

            eventContinuations[id] =
                continuation

            continuation.onTermination = {
                [weak self] _ in

                Task { @MainActor [weak self] in
                    self?
                        .eventContinuations
                        .removeValue(
                            forKey: id
                        )
                }
            }
        }
    }

    func synchronize(
        regions: [BackgroundMonitoredRegion]
    ) async throws {

        guard
            client
                .isCircularRegionMonitoringAvailable
        else {
            throw BackgroundRegionMonitoringError
                .monitoringUnavailable
        }

        let maximumDistance =
            client
                .maximumRegionMonitoringDistance

        guard maximumDistance > 0 else {
            throw BackgroundRegionMonitoringError
                .monitoringUnavailable
        }

        let desiredRegions =
            try makeDesiredRegions(
                from: regions,
                maximumDistance:
                    maximumDistance
            )

        let allExistingRegions =
            client.monitoredRegions

        let ownedExistingRegions =
            allExistingRegions.filter {
                Self.isOwnedRegion($0)
            }

        let foreignRegionCount =
            allExistingRegions.count
            - ownedExistingRegions.count

        let availableCapacity = max(
            0,
            BackgroundRecognitionPolicy
                .systemMaximumMonitoredPlaces
            - foreignRegionCount
        )

        guard
            desiredRegions.count
                <= availableCapacity
        else {
            throw BackgroundRegionMonitoringError
                .insufficientSystemCapacity(
                    requested:
                        desiredRegions.count,
                    available:
                        availableCapacity
                )
        }

        var existingByIdentifier:
            [String: CLRegion] = [:]

        for region in ownedExistingRegions {
            existingByIdentifier[
                region.identifier
            ] = region
        }

        let desiredIdentifiers =
            Set(desiredRegions.keys)

        let staleRegions =
            ownedExistingRegions
                .filter {
                    !desiredIdentifiers
                        .contains(
                            $0.identifier
                        )
                }
                .sorted {
                    $0.identifier
                        < $1.identifier
                }

        for region in staleRegions {
            client.stopMonitoring(
                for: region
            )
        }

        for identifier
            in desiredRegions.keys.sorted() {

            guard
                let desiredRegion =
                    desiredRegions[identifier]
            else {
                continue
            }

            if let existingRegion =
                existingByIdentifier[
                    identifier
                ] as? CLCircularRegion,
               Self.isEquivalent(
                    existingRegion,
                    desiredRegion
               ) {

                continue
            }

            client.startMonitoring(
                for: desiredRegion
            )
        }
    }

    func stopAll() async {

        let ownedRegions =
            client
                .monitoredRegions
                .filter {
                    Self.isOwnedRegion($0)
                }
                .sorted {
                    $0.identifier
                        < $1.identifier
                }

        for region in ownedRegions {
            client.stopMonitoring(
                for: region
            )
        }
    }

    static func regionIdentifier(
        for placeID: UUID
    ) -> String {

        identifierPrefix
            + placeID.uuidString
    }

    static func placeID(
        from identifier: String
    ) -> UUID? {

        guard
            identifier.hasPrefix(
                identifierPrefix
            )
        else {
            return nil
        }

        let value =
            String(
                identifier.dropFirst(
                    identifierPrefix.count
                )
            )

        return UUID(
            uuidString: value
        )
    }
}

private extension
    CoreLocationBackgroundRegionMonitor {

    func bindClient() {

        client.onRegionEntered = {
            [weak self] region in

            self?.handleRegionEntered(
                region
            )
        }

        client.onRegionExited = {
            [weak self] region in

            self?.handleRegionExited(
                region
            )
        }

        client.onMonitoringFailure = {
            [weak self] region, _ in

            self?.handleMonitoringFailure(
                region
            )
        }
    }

    func makeDesiredRegions(
        from regions:
            [BackgroundMonitoredRegion],
        maximumDistance:
            CLLocationDistance
    ) throws -> [String: CLCircularRegion] {

        var result:
            [String: CLCircularRegion] = [:]

        for region in regions {

            guard
                Self.isValidCoordinate(
                    latitude: region.latitude,
                    longitude: region.longitude
                )
            else {
                throw BackgroundRegionMonitoringError
                    .invalidCoordinate(
                        placeID: region.placeID
                    )
            }

            guard
                region.radius.isFinite,
                region.radius > 0
            else {
                throw BackgroundRegionMonitoringError
                    .invalidRadius(
                        placeID: region.placeID
                    )
            }

            guard
                region.radius
                    <= maximumDistance
            else {
                throw BackgroundRegionMonitoringError
                    .radiusExceedsMaximum(
                        placeID: region.placeID,
                        maximum:
                            maximumDistance
                    )
            }

            let identifier =
                Self.regionIdentifier(
                    for: region.placeID
                )

            let circularRegion =
                CLCircularRegion(
                    center:
                        CLLocationCoordinate2D(
                            latitude:
                                region.latitude,
                            longitude:
                                region.longitude
                        ),
                    radius:
                        region.radius,
                    identifier:
                        identifier
                )

            circularRegion.notifyOnEntry = true
            circularRegion.notifyOnExit = true

            result[identifier] =
                circularRegion
        }

        return result
    }

    func handleRegionEntered(
        _ region: CLRegion
    ) {

        guard
            let placeID =
                Self.placeID(
                    from: region.identifier
                )
        else {
            return
        }

        yield(
            .monitoredRegionEntered(
                placeID: placeID
            )
        )
    }

    func handleRegionExited(
        _ region: CLRegion
    ) {

        guard
            let placeID =
                Self.placeID(
                    from: region.identifier
                )
        else {
            return
        }

        yield(
            .monitoredRegionExited(
                placeID: placeID
            )
        )
    }

    func handleMonitoringFailure(
        _ region: CLRegion?
    ) {

        if let region {
            guard
                Self.isOwnedRegion(region)
            else {
                return
            }
        }

        let placeID =
            region.flatMap {
                Self.placeID(
                    from: $0.identifier
                )
            }

        finishEvents(
            throwing:
                BackgroundRegionMonitoringError
                    .systemMonitoringFailed(
                        placeID: placeID
                    )
        )
    }

    func yield(
        _ trigger:
            BackgroundRecognitionTrigger
    ) {

        let continuations =
            Array(
                eventContinuations.values
            )

        for continuation in continuations {
            continuation.yield(
                trigger
            )
        }
    }

    func finishEvents(
        throwing error:
            BackgroundRegionMonitoringError
    ) {

        let continuations =
            Array(
                eventContinuations.values
            )

        eventContinuations.removeAll()

        for continuation in continuations {
            continuation.finish(
                throwing: error
            )
        }
    }

    static func isOwnedRegion(
        _ region: CLRegion
    ) -> Bool {

        region.identifier.hasPrefix(
            identifierPrefix
        )
    }

    static func isEquivalent(
        _ lhs: CLCircularRegion,
        _ rhs: CLCircularRegion
    ) -> Bool {

        lhs.center.latitude
            == rhs.center.latitude
        && lhs.center.longitude
            == rhs.center.longitude
        && lhs.radius
            == rhs.radius
        && lhs.notifyOnEntry
            == rhs.notifyOnEntry
        && lhs.notifyOnExit
            == rhs.notifyOnExit
    }

    static func isValidCoordinate(
        latitude: Double,
        longitude: Double
    ) -> Bool {

        latitude.isFinite
        && longitude.isFinite
        && (-90...90).contains(
            latitude
        )
        && (-180...180).contains(
            longitude
        )
    }
}

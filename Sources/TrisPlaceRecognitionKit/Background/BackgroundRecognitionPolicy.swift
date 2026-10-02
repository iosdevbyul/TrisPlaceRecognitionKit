//
//  BackgroundRecognitionPolicy.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

public struct BackgroundRecognitionPolicy:
    Sendable,
    Equatable {

    /// Core Location allows an app to monitor
    /// at most 20 conditions at the same time.
    public static let systemMaximumMonitoredPlaces = 20

    /// Maximum number of places this package
    /// may select for background monitoring.
    ///
    /// This does not enable continuous location
    /// updates. It only limits system-monitored
    /// place candidates.
    public let maximumMonitoredPlaces: Int

    public init(
        maximumMonitoredPlaces: Int =
            Self.systemMaximumMonitoredPlaces
    ) {

        if (1...Self.systemMaximumMonitoredPlaces)
            .contains(maximumMonitoredPlaces) {

            self.maximumMonitoredPlaces =
                maximumMonitoredPlaces

        } else {

            self.maximumMonitoredPlaces =
                Self.systemMaximumMonitoredPlaces
        }
    }
}

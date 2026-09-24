//
//  PlaceRecognitionMonitor.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-24.
//


import Combine
import Foundation

@MainActor
public final class PlaceRecognitionMonitor: ObservableObject {

    @Published
    public private(set) var recognizedPlaces: [RecognizedPlace] = []

    @Published
    public private(set) var isMonitoring = false

    @Published
    public private(set) var lastErrorMessage: String?

    private let recognitionService: PlaceRecognitionService
    private let policy: PlaceRecognitionPolicy
    private let refreshInterval: TimeInterval

    private var monitoringTask: Task<Void, Never>?

    // Prevent an older asynchronous request from
    // overwriting a newer recognition result.
    private var refreshRevision: UInt64 = 0

    public init(
        recognitionService: PlaceRecognitionService,
        policy: PlaceRecognitionPolicy = .gpsConstrained,
        refreshInterval: TimeInterval = 15
    ) {
        self.recognitionService = recognitionService
        self.policy = policy

        if refreshInterval.isFinite,
           (5...3600).contains(refreshInterval) {
            self.refreshInterval = refreshInterval
        } else {
            self.refreshInterval = 15
        }
    }

    public func start() async {
        guard !isMonitoring else {
            return
        }

        isMonitoring = true

        // Recognize immediately instead of waiting
        // for the first polling interval.
        await refresh()

        guard isMonitoring,
              !Task.isCancelled else {
            stop()
            return
        }

        let sleepNanoseconds = UInt64(
            refreshInterval * 1_000_000_000
        )

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: sleepNanoseconds
                    )
                } catch {
                    return
                }

                guard !Task.isCancelled,
                      let self,
                      self.isMonitoring else {
                    return
                }

                await self.refresh()
            }
        }
    }

    public func refresh() async {
        refreshRevision &+= 1
        let revision = refreshRevision

        do {
            let places = try await recognitionService
                .recognizeCurrentPlaces(
                    policy: policy
                )

            guard revision == refreshRevision,
                  !Task.isCancelled else {
                return
            }

            if recognizedPlaces != places {
                recognizedPlaces = places
            }

            lastErrorMessage = nil
        } catch {
            guard revision == refreshRevision,
                  !Task.isCancelled else {
                return
            }

            // Never expose an old place as the
            // current place after recognition fails.
            recognizedPlaces = []
            lastErrorMessage = error.localizedDescription
        }
    }

    public func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil

        refreshRevision &+= 1

        isMonitoring = false
        recognizedPlaces = []
        lastErrorMessage = nil
    }
}

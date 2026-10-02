//
//  BackgroundRecognitionEventProcessor.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

@MainActor
final class BackgroundRecognitionEventProcessor {

    private let recognitionService:
        PlaceRecognitionService

    private let coordinator:
        PlaceVisitCoordinator

    private let recognitionPolicy:
        PlaceRecognitionPolicy

    init(
        recognitionService:
            PlaceRecognitionService,
        coordinator:
            PlaceVisitCoordinator,
        recognitionPolicy:
            PlaceRecognitionPolicy
    ) {
        self.recognitionService =
            recognitionService

        self.coordinator =
            coordinator

        self.recognitionPolicy =
            recognitionPolicy
    }

    @discardableResult
    func handle(
        _ trigger: BackgroundRecognitionTrigger,
        at timestamp: Date = Date()
    ) async throws -> PlaceVisitUpdate {

        try Task.checkCancellation()

        switch trigger {

        case .significantLocationChange:

            // Significant movement is not visit evidence.
            // It will later be used only to refresh the
            // set of monitored place candidates.
            return PlaceVisitUpdate()

        case .monitoredRegionEntered,
             .monitoredRegionExited:

            break
        }

        // One real recognition request is performed only
        // because a relevant system event occurred.
        //
        // This never starts continuous location updates.
        let recognizedPlaces =
            try await recognitionService
                .recognizeCurrentPlaces(
                    policy: recognitionPolicy
                )

        try Task.checkCancellation()

        // A recognition error never reaches this point,
        // so failure can never be interpreted as an empty
        // successful observation.
        return try await coordinator
            .processVerifiedBackgroundObservation(
                recognizedPlaces,
                trigger: trigger,
                at: timestamp
            )
    }
}

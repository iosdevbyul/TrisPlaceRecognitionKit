//
//  BackgroundRecognitionEventProcessor.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-02.
//

import Foundation

struct BackgroundRecognitionProcessingResult {

    let recognizedPlaces:
        [RecognizedPlace]

    let visitUpdate:
        PlaceVisitUpdate

    var events:
        [PlaceVisitEvent] {

        visitUpdate.events
    }

    var startedVisits:
        [PlaceVisitRecord] {

        visitUpdate.startedVisits
    }

    var endedVisits:
        [PlaceVisitRecord] {

        visitUpdate.endedVisits
    }
}

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

    func handle(
        _ trigger:
            BackgroundRecognitionTrigger,
        at timestamp:
            Date? = nil
    ) async throws
        -> BackgroundRecognitionProcessingResult {

        try Task.checkCancellation()

        switch trigger {

        case .significantLocationChange,
             .monitoredRegionEntered,
             .monitoredRegionExited:

            break
        }

        let recognizedPlaces =
            try await recognitionService
                .recognizeCurrentPlaces(
                    policy:
                        recognitionPolicy
                )

        try Task.checkCancellation()

        let observedAt =
            timestamp ?? Date()

        let update =
            try await coordinator
                .processVerifiedBackgroundObservation(
                    recognizedPlaces,
                    trigger:
                        trigger,
                    at:
                        observedAt
                )

        return BackgroundRecognitionProcessingResult(
            recognizedPlaces:
                recognizedPlaces,
            visitUpdate:
                update
        )
    }
}

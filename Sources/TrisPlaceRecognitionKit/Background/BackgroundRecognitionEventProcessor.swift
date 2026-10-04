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
            Date = Date()
    ) async throws
        -> BackgroundRecognitionProcessingResult {

        try Task.checkCancellation()

        switch trigger {

        case .significantLocationChange:

            return BackgroundRecognitionProcessingResult(
                recognizedPlaces:
                    [],
                visitUpdate:
                    PlaceVisitUpdate()
            )

        case .monitoredRegionEntered,
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

        let update =
            try await coordinator
                .processVerifiedBackgroundObservation(
                    recognizedPlaces,
                    trigger:
                        trigger,
                    at:
                        timestamp
                )

        return BackgroundRecognitionProcessingResult(
            recognizedPlaces:
                recognizedPlaces,
            visitUpdate:
                update
        )
    }
}

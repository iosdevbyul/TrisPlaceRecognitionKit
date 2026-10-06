//
//  UserNotificationPlaceVisitNotifier.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-05.
//

import Foundation
import TrisNotificationKit

struct UserNotificationPlaceVisitNotifier:
    PlaceVisitNotifying {

    func notifyArrival(
        placeName: String
    ) async throws {

        let notificationService =
            LocalNotificationService()

        try await notificationService
            .send(
                title:
                    "장소 도착",
                body:
                    "\(placeName)에 도착했습니다.",
                identifier:
                    makeIdentifier()
            )
    }

    func notifyDeparture(
        placeName: String
    ) async throws {

        let notificationService =
            LocalNotificationService()

        try await notificationService
            .send(
                title:
                    "장소 이탈",
                body:
                    "\(placeName)에서 나왔습니다.",
                identifier:
                    makeIdentifier()
            )
    }

    private func makeIdentifier()
        -> String {

        "TrisPlaceRecognitionKit.visit.\(UUID().uuidString)"
    }
}

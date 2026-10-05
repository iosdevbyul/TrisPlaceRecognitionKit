//
//  UserNotificationPlaceVisitNotifier.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-05.
//

import Foundation
import UserNotifications

struct UserNotificationPlaceVisitNotifier:
    PlaceVisitNotifying {

    func notifyArrival(
        placeName: String
    ) async throws {

        let content =
            UNMutableNotificationContent()

        content.title =
            "장소 도착"

        content.body =
            "\(placeName)에 도착했습니다."

        content.sound =
            .default

        let request =
            UNNotificationRequest(
                identifier:
                    makeIdentifier(),
                content:
                    content,
                trigger:
                    nil
            )

        try await UNUserNotificationCenter
            .current()
            .add(
                request
            )
    }

    func notifyDeparture(
        placeName: String
    ) async throws {

        let content =
            UNMutableNotificationContent()

        content.title =
            "장소 이탈"

        content.body =
            "\(placeName)에서 나왔습니다."

        content.sound =
            .default

        let request =
            UNNotificationRequest(
                identifier:
                    makeIdentifier(),
                content:
                    content,
                trigger:
                    nil
            )

        try await UNUserNotificationCenter
            .current()
            .add(
                request
            )
    }

    private func makeIdentifier()
        -> String {

        "TrisPlaceRecognitionKit.visit.\(UUID().uuidString)"
    }
}

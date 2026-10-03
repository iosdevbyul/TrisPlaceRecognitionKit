//
//  DemoAppDelegate.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-10-03.
//

import UIKit

@MainActor
final class DemoAppDelegate:
    NSObject,
    UIApplicationDelegate {

    let environment =
        DemoEnvironment()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions
            launchOptions:
                [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let wasLaunchedForLocationEvent =
            launchOptions?[.location] != nil

        Task {

            await environment
                .handleApplicationLaunch(
                    wasLaunchedForLocationEvent:
                        wasLaunchedForLocationEvent
                )
        }

        return true
    }
}

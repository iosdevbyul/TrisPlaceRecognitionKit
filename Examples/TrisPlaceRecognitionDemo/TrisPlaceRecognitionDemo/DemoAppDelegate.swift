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

        Task {

            await environment
                .handleApplicationLaunch()
        }

        return true
    }
}

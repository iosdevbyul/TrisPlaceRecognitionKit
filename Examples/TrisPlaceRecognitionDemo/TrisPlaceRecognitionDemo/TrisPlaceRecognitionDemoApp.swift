//
//  TrisPlaceRecognitionDemoApp.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-09-27.
//

import SwiftUI

@main
struct TrisPlaceRecognitionDemoApp: App {

    @UIApplicationDelegateAdaptor(
        DemoAppDelegate.self
    )
    private var appDelegate

    var body: some Scene {

        WindowGroup {

            ContentView(
                environment:
                    appDelegate.environment
            )
        }
    }
}

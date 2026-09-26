//
//  ContentView.swift
//  TrisPlaceRecognitionDemo
//
//  Created by COMATOKI on 2026-09-27.
//


import SwiftUI
import TrisPlaceRecognitionKit

@MainActor
struct ContentView: View {

    @StateObject
    private var environment = DemoEnvironment()

    var body: some View {
        Group {
            if let store = environment.store {
                PlaceManagementView(
                    placeStore: store,
                    locationProvider: environment.locationProvider,
                    wifiProvider: environment.wifiProvider
                )
            } else {
                VStack(spacing: 16) {
                    Text("TrisPlaceRecognitionKit")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("장소 등록 및 인식 데모")
                        .foregroundStyle(.secondary)

                    if let error = environment.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if environment.isPreparing {
                        ProgressView("준비 중")
                    } else {
                        Button("데모 시작") {
                            Task {
                                await environment.start()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
    }
}

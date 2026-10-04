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

    @Environment(\.scenePhase)
    private var scenePhase

    @ObservedObject
    var environment:
        DemoEnvironment

    var body:
        some View {

        Group {

            if let store =
                environment.store,
               let visitManager =
                environment.visitManager {

                TabView {

                    PlaceManagementView(
                        placeStore:
                            store,
                        locationProvider:
                            environment.locationProvider,
                        wifiProvider:
                            environment.wifiProvider,
                        visitManager:
                            visitManager
                    )
                    .tabItem {

                        Label(
                            "장소",
                            systemImage:
                                "mappin.and.ellipse"
                        )
                    }

                    DemoVisitHistoryView(
                        placeStore:
                            store,
                        visitManager:
                            visitManager
                    )
                    .tabItem {

                        Label(
                            "방문 기록",
                            systemImage:
                                "clock.arrow.circlepath"
                        )
                    }

                    DemoBackgroundValidationView(
                        environment:
                            environment,
                        placeStore:
                            store,
                        visitManager:
                            visitManager
                    )
                    .tabItem {

                        Label(
                            "검증",
                            systemImage:
                                "checklist"
                        )
                    }
                }
                .task {

                    try? await visitManager
                        .refresh()
                }

            } else {

                preparationView
            }
        }
        .onChange(
            of:
                scenePhase
        ) { _, newPhase in

            guard
                newPhase
                    == .active
            else {
                return
            }

            Task {

                await environment
                    .retryBackgroundRecognition()

                if let visitManager =
                    environment.visitManager {

                    try? await visitManager
                        .refresh()
                }
            }
        }
    }
}

private extension ContentView {

    var preparationView:
        some View {

        VStack(
            spacing: 16
        ) {

            Text(
                "TrisPlaceRecognitionKit"
            )
            .font(
                .title2
            )
            .fontWeight(
                .bold
            )

            Text(
                "장소 등록 및 방문 인식 데모"
            )
            .foregroundStyle(
                .secondary
            )

            if let error =
                environment.errorMessage {

                Text(
                    error
                )
                .foregroundStyle(
                    .red
                )
                .multilineTextAlignment(
                    .center
                )
            }

            if environment.isPreparing {

                ProgressView(
                    "준비 중"
                )

            } else {

                Button(
                    "데모 시작"
                ) {

                    Task {

                        await environment
                            .start()
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
            }
        }
        .padding()
    }
}

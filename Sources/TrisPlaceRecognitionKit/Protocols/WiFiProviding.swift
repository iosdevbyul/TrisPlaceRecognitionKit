//
//  WiFiProviding.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

public protocol WiFiProviding: Sendable {

    func currentNetwork() async -> WiFiNetwork?
}

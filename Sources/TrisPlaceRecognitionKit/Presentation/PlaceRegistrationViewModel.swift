//
//  PlaceRegistrationViewModel.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-26.
//

import Combine
import Foundation

@MainActor
public final class PlaceRegistrationViewModel: ObservableObject {

    public enum Phase: Equatable {
        case editing
        case preparing
        case reviewing
        case saving
        case completed
    }

    @Published
    public var name = ""

    @Published
    public var method: PlaceRegistrationMethod = .automatic

    @Published
    public var recognitionRadius: Double = 100

    @Published
    public private(set) var phase: Phase = .editing

    @Published
    public private(set) var candidate: RegisteredPlace?

    @Published
    public private(set) var warnings: [PlaceDuplicateWarning] = []

    @Published
    public private(set) var registeredPlace: RegisteredPlace?

    @Published
    public private(set) var errorMessage: String?

    private let registrationService: PlaceRegistrationService
    private let duplicateCheckService: PlaceDuplicateCheckService

    private var preparationRevision: UInt64 = 0

    public var canPrepare: Bool {
        phase == .editing
            && (try? PlaceName(name)) != nil
            && recognitionRadius.isFinite
            && recognitionRadius > 0
    }

    public init(
        registrationService: PlaceRegistrationService,
        duplicateCheckService: PlaceDuplicateCheckService
    ) {
        self.registrationService = registrationService
        self.duplicateCheckService = duplicateCheckService
    }

    public func prepare() async {
        guard phase == .editing else {
            return
        }

        guard (try? PlaceName(name)) != nil else {
            errorMessage = PlaceL10n.string("place.error.name_length")
            return
        }

        guard recognitionRadius.isFinite,
              recognitionRadius > 0 else {
            errorMessage = PlaceL10n.string("place.error.radius")
            return
        }

        let requestedName = name
        let requestedMethod = method
        let requestedRadius = recognitionRadius

        preparationRevision &+= 1
        let revision = preparationRevision

        phase = .preparing
        errorMessage = nil

        do {
            let prepared = try await registrationService
                .prepareRegistration(
                    name: requestedName,
                    recognitionRadius: requestedRadius,
                    method: requestedMethod
                )

            guard revision == preparationRevision else {
                return
            }

            let detectedWarnings = try await duplicateCheckService
                .check(candidate: prepared)

            guard revision == preparationRevision else {
                return
            }

            candidate = prepared
            warnings = detectedWarnings
            phase = .reviewing
        } catch {
            guard revision == preparationRevision else {
                return
            }

            candidate = nil
            warnings = []
            errorMessage = message(for: error)
            phase = .editing
        }
    }

    public func cancelPreview() {
        guard phase == .preparing
                || phase == .reviewing else {
            return
        }

        preparationRevision &+= 1

        candidate = nil
        warnings = []
        errorMessage = nil
        phase = .editing
    }

    public func confirmRegistration() async {
        guard phase == .reviewing,
              let candidate else {
            return
        }

        phase = .saving
        errorMessage = nil

        do {
            // Recheck immediately before saving.
            // Another place may have been registered
            // while the confirmation screen was open.
            let latestWarnings = try await duplicateCheckService
                .check(candidate: candidate)

            guard latestWarnings == warnings else {
                warnings = latestWarnings

                errorMessage =
                    PlaceL10n.string(
                        "place.error.duplicate_changed"
                    )

                phase = .reviewing
                return
            }

            let saved = try await registrationService
                .savePrepared(candidate)

            registeredPlace = saved
            phase = .completed
        } catch {
            errorMessage = message(for: error)
            phase = .reviewing
        }
    }
}

private extension PlaceRegistrationViewModel {

    func message(for error: Error) -> String {
        if let registrationError = error as? PlaceRegistrationError {
            switch registrationError {
            case .emptyName:
                return PlaceL10n.string("place.error.name_required")

            case .nameTooLong:
                return PlaceL10n.string("place.error.name_max")

            case .currentWiFiUnavailable:
                return PlaceL10n.string("place.error.wifi_unavailable")

            case .noAvailableSignal:
                return PlaceL10n.string("place.error.signal_unavailable")
            }
        }

        return error.localizedDescription
    }
}

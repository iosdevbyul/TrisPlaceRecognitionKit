//
//  PlaceNameTests.swift
//  TrisPlaceRecognitionKit
//
//  Created by COMATOKI on 2026-09-22.
//

import Testing

@testable import TrisPlaceRecognitionKit

struct PlaceNameTests {

    @Test
    func trimsWhitespaceAndNewlines() throws {
        let name = try PlaceName(
            "  헬스장 \n"
        )

        #expect(
            name.value == "헬스장"
        )
    }

    @Test
    func acceptsNameWithMaximumLength() throws {
        let name = try PlaceName(
            "가나다라마바사아자차"
        )

        #expect(
            name.value == "가나다라마바사아자차"
        )

        #expect(
            name.value.count == PlaceName.maximumLength
        )
    }

    @Test
    func rejectsEmptyName() {
        do {
            _ = try PlaceName("")

            Issue.record(
                "Expected emptyName error"
            )
        } catch let error as PlaceRegistrationError {
            #expect(
                error == .emptyName
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    @Test
    func rejectsWhitespaceOnlyName() {
        do {
            _ = try PlaceName(
                "   \n   "
            )

            Issue.record(
                "Expected emptyName error"
            )
        } catch let error as PlaceRegistrationError {
            #expect(
                error == .emptyName
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    @Test
    func rejectsNameLongerThanMaximumLength() {
        do {
            _ = try PlaceName(
                "가나다라마바사아자차카"
            )

            Issue.record(
                "Expected nameTooLong error"
            )
        } catch let error as PlaceRegistrationError {
            #expect(
                error == .nameTooLong
            )
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }
}

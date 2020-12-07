/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class TracingWithRUMErrorsIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        temporaryDirectory.create()
        RUMFeature.instance = .mockByRecordingRUMEventMatchers(directory: temporaryDirectory)
        GlobalDatadog.rum = RUMMonitor.initialize()
        GlobalDatadog.rum.startView(viewController: mockView)
    }

    override func tearDown() {
        temporaryDirectory.delete()
        RUMFeature.instance = nil
        GlobalDatadog.rum = DDNoopRUMMonitor()
        super.tearDown()
    }

    func testWhenSpanErrorHasMessageAndType() throws {
        let integration = TracingWithRUMErrorsIntegration()
        integration.addError(
            for: .mockWith(
                operationName: "operation name",
                tags: [
                    DDTags.errorMessage: "message",
                    DDTags.errorType: "type"
                ]
            )
        )

        let rumError = try waitAndReturnRUMErrorSent()
        XCTAssertEqual(rumError.error.message, #"Span error (operation name): type | message"#)
        XCTAssertEqual(rumError.error.source, .source)
        XCTAssertNil(rumError.error.stack)
    }

    func testWhenSpanErrorHasMessageButNoType() throws {
        let integration = TracingWithRUMErrorsIntegration()
        integration.addError(
            for: .mockWith(operationName: "operation name", tags: [DDTags.errorMessage: "message"])
        )

        let rumError = try waitAndReturnRUMErrorSent()
        XCTAssertEqual(rumError.error.message, #"Span error (operation name): message"#)
        XCTAssertEqual(rumError.error.source, .source)
        XCTAssertNil(rumError.error.stack)
    }

    func testWhenSpanErrorHasTypeButNoMessage() throws {
        let integration = TracingWithRUMErrorsIntegration()
        integration.addError(
            for: .mockWith(operationName: "operation name", tags: [DDTags.errorType: "type"])
        )

        let rumError = try waitAndReturnRUMErrorSent()
        XCTAssertEqual(rumError.error.message, #"Span error (operation name): type"#)
        XCTAssertEqual(rumError.error.source, .source)
        XCTAssertNil(rumError.error.stack)
    }

    func testWhenSpanErrorHasTypeNoMessageAndNoType() throws {
        let integration = TracingWithRUMErrorsIntegration()
        integration.addError(
            for: .mockWith(operationName: "operation name", tags: [:])
        )

        let rumError = try waitAndReturnRUMErrorSent()
        XCTAssertEqual(rumError.error.message, #"Span error (operation name)"#)
        XCTAssertEqual(rumError.error.source, .source)
        XCTAssertNil(rumError.error.stack)
    }

    // MARK: - Helpers

    private func waitAndReturnRUMErrorSent() throws -> RUMDataError {
        // [RUMView, RUMAction, RUMError] events sent:
        let rumEventMatchers = try RUMFeature.waitAndReturnRUMEventMatchers(count: 3)
        let rumErrorMatcher = try XCTUnwrap(rumEventMatchers.first { $0.model(isTypeOf: RUMDataError.self) })
        return try rumErrorMatcher.model()
    }
}

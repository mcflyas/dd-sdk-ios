/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class RUMIntegrationsTests: XCTestCase {
    private let integration = RUMContextIntegration()

    func testGivenRUMMonitorRegistered_itProvidesRUMContextAttributes() throws {
        RUMFeature.instance = .mockNoOp()
        defer { RUMFeature.instance = nil }

        // given
        GlobalDatadog.rum = RUMMonitor.initialize()
        GlobalDatadog.rum.startView(viewController: mockView)
        defer { GlobalDatadog.rum = DDNoopRUMMonitor() }

        // then
        let attributes = try XCTUnwrap(integration.currentRUMContextAttributes)

        XCTAssertEqual(attributes.count, 3)
        XCTAssertEqual(
            attributes["application_id"] as? String,
            try XCTUnwrap(RUMFeature.instance?.configuration.applicationID)
        )
        XCTAssertValidRumUUID(attributes["session_id"] as? String)
        XCTAssertValidRumUUID(attributes["view.id"] as? String)
    }

    func testGivenRUMMonitorRegistered_whenSessionIsSampled_itProvidesEmptyRUMContextAttributes() throws {
        RUMFeature.instance = RUMFeature(
            storage: FeatureStorage(writer: NoOpFileWriter(), reader: NoOpFileReader()),
            upload: FeatureUpload(uploader: NoOpDataUploadWorker()),
            configuration: .mockWith(sessionSamplingRate: 0.0),
            commonDependencies: .mockAny()
        )
        defer { RUMFeature.instance = nil }

        // given
        GlobalDatadog.rum = RUMMonitor.initialize()
        GlobalDatadog.rum.startView(viewController: mockView)
        defer { GlobalDatadog.rum = DDNoopRUMMonitor() }

        // then
        let attributes = try XCTUnwrap(integration.currentRUMContextAttributes)

        XCTAssertTrue(attributes.isEmpty)
    }

    func testWhenRUMMonitorIsNotRegistered_itReturnsNil() throws {
        RUMFeature.instance = .mockNoOp()
        defer { RUMFeature.instance = nil }

        // when
        XCTAssertTrue(GlobalDatadog.rum is DDNoopRUMMonitor)

        // then
        XCTAssertNil(integration.currentRUMContextAttributes)
    }
}

class RUMErrorsIntegrationTests: XCTestCase {
    private let integration = RUMErrorsIntegration()

    override class func setUp() {
        super.setUp()
        temporaryDirectory.create()
    }

    override class func tearDown() {
        super.tearDown()
        temporaryDirectory.delete()
    }

    func testGivenRUMMonitorRegistered_whenAddingErrorMessage_itSendsRUMErrorForCurrentView() throws {
        RUMFeature.instance = .mockByRecordingRUMEventMatchers(directory: temporaryDirectory)
        defer { RUMFeature.instance = nil }

        // given
        GlobalDatadog.rum = RUMMonitor.initialize()
        GlobalDatadog.rum.startView(viewController: mockView)
        defer { GlobalDatadog.rum = DDNoopRUMMonitor() }

        // when
        integration.addError(with: "error message", stack: "Foo.swift:10", source: .logger)

        // then
        let rumEventMatchers = try RUMFeature.waitAndReturnRUMEventMatchers(count: 3) // [RUMView, RUMAction, RUMError] events sent
        let rumErrorMatcher = rumEventMatchers.first { $0.model(isTypeOf: RUMDataError.self) }
        try XCTUnwrap(rumErrorMatcher).model(ofType: RUMDataError.self) { rumModel in
            XCTAssertEqual(rumModel.error.message, "error message")
            XCTAssertEqual(rumModel.error.source, .logger)
            XCTAssertEqual(rumModel.error.stack, "Foo.swift:10")
        }
    }
}

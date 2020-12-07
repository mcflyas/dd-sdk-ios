/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class RUMAutoInstrumentationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        XCTAssertNil(RUMFeature.instance)
        XCTAssertNil(RUMAutoInstrumentation.instance)
    }

    override func tearDown() {
        XCTAssertNil(RUMAutoInstrumentation.instance)
        XCTAssertNil(RUMFeature.instance)
        super.tearDown()
    }

    func testGivenRUMViewsAutoInstrumentationEnabled_whenRUMMonitorIsRegistered_itSubscribesAsViewsHandler() throws {
        // Given
        RUMFeature.instance = .mockNoOp()
        defer { RUMFeature.instance = nil }

        RUMAutoInstrumentation.instance = RUMAutoInstrumentation(
            configuration: .init(
                uiKitRUMViewsPredicate: UIKitRUMViewsPredicateMock(),
                uiKitActionsTrackingEnabled: false
            ),
            dateProvider: SystemDateProvider()
        )
        defer { RUMAutoInstrumentation.instance = nil }

        // When
        GlobalDatadog.rum = RUMMonitor.initialize()
        defer { GlobalDatadog.rum = DDNoopRUMMonitor() }

        // Then
        let viewsHandler = RUMAutoInstrumentation.instance?.views?.handler as? UIKitRUMViewsHandler
        XCTAssertTrue(viewsHandler?.subscriber === GlobalDatadog.rum)
    }

    func testGivenRUMUserActionsAutoInstrumentationEnabled_whenRUMMonitorIsRegistered_itSubscribesAsUserActionsHandler() throws {
        // Given
        RUMFeature.instance = .mockNoOp()
        defer { RUMFeature.instance = nil }

        RUMAutoInstrumentation.instance = RUMAutoInstrumentation(
            configuration: .init(
                uiKitRUMViewsPredicate: nil,
                uiKitActionsTrackingEnabled: true
            ),
            dateProvider: SystemDateProvider()
        )
        defer { RUMAutoInstrumentation.instance = nil }

        // When
        GlobalDatadog.rum = RUMMonitor.initialize()
        defer { GlobalDatadog.rum = DDNoopRUMMonitor() }

        // Then
        let userActionsHandler = RUMAutoInstrumentation.instance?.userActions?.handler as? UIKitRUMUserActionsHandler
        XCTAssertTrue(userActionsHandler?.subscriber === GlobalDatadog.rum)
    }

    /// Sanity check for not-allowed configuration.
    func testWhenAllRUMAutoInstrumentationsDisabled_itDoesNotCreateInstrumentationComponents() throws {
        // Given
        RUMFeature.instance = .mockNoOp()
        defer { RUMFeature.instance = nil }

        /// This configuration is not allowed by `FeaturesConfiguration` logic. We test it for sanity.
        let notAllowedConfiguration = FeaturesConfiguration.RUM.AutoInstrumentation(
            uiKitRUMViewsPredicate: nil,
            uiKitActionsTrackingEnabled: false
        )

        RUMAutoInstrumentation.instance = RUMAutoInstrumentation(
            configuration: notAllowedConfiguration,
            dateProvider: SystemDateProvider()
        )
        defer { RUMAutoInstrumentation.instance = nil }

        // Then
        XCTAssertNil(RUMAutoInstrumentation.instance?.views)
        XCTAssertNil(RUMAutoInstrumentation.instance?.userActions)
    }
}

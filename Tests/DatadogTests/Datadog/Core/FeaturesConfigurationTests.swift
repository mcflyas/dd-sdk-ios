/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

extension FeaturesConfiguration.Common: EquatableInTests {}

class FeaturesConfigurationTests: XCTestCase {
    // MARK: - Common Configuration

    func testApplicationName() throws {
        var configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleName: "app-name")
        )
        XCTAssertEqual(configuration.common.applicationName, "app-name", "should use Bundle Name")

        configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleType: .iOSApp, bundleName: nil)
        )
        XCTAssertEqual(configuration.common.applicationName, "iOSApp", "should fallback to Bundle Type")
    }

    func testApplicationVersion() throws {
        var configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleVersion: "1.2.3")
        )
        XCTAssertEqual(configuration.common.applicationVersion, "1.2.3", "should use Bundle version")

        configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleVersion: nil)
        )
        XCTAssertEqual(configuration.common.applicationVersion, "0.0.0", "should fallback to '0.0.0'")
    }

    func testApplicationBundleIdentifier() throws {
        var configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleIdentifier: "com.datadoghq.tests")
        )
        XCTAssertEqual(configuration.common.applicationBundleIdentifier, "com.datadoghq.tests", "should use Bundle identifier")

        configuration = try FeaturesConfiguration(
            configuration: .mockAny(),
            appContext: .mockWith(bundleIdentifier: nil)
        )
        XCTAssertEqual(configuration.common.applicationBundleIdentifier, "unknown", "should fallback to 'unknown'")
    }

    func testServiceName() throws {
        var configuration = try FeaturesConfiguration(
            configuration: .mockWith(serviceName: "service-name"),
            appContext: .mockWith(bundleIdentifier: "com.datadoghq.tests")
        )
        XCTAssertEqual(configuration.common.serviceName, "service-name", "should prioritize the value from `Datadog.Configuration`")

        configuration = try FeaturesConfiguration(
            configuration: .mockWith(serviceName: nil),
            appContext: .mockWith(bundleIdentifier: "com.datadoghq.tests")
        )
        XCTAssertEqual(configuration.common.serviceName, "com.datadoghq.tests", "should fallback to Bundle identifier")

        configuration = try FeaturesConfiguration(
            configuration: .mockWith(serviceName: nil),
            appContext: .mockWith(bundleIdentifier: nil)
        )
        XCTAssertEqual(configuration.common.serviceName, "ios", "should fallback to 'ios'")
    }

    func testEnvironment() throws {
        func verify(validEnvironmentName environment: String) throws {
            let configuration = try FeaturesConfiguration(
                configuration: .mockWith(environment: environment),
                appContext: .mockAny()
            )
            XCTAssertEqual(configuration.common.environment, environment, "should use the value from `Datadog.Configuration`")
        }
        func verify(invalidEnvironmentName environment: String) {
            XCTAssertThrowsError(try FeaturesConfiguration(configuration: .mockWith(environment: environment), appContext: .mockAny())) { error in
                XCTAssertEqual(
                    (error as? ProgrammerError)?.description,
                    "🔥 Datadog SDK usage error: `environment`: \(environment) contains illegal characters (only alphanumerics and `_` are allowed)"
                )
            }
        }

        try verify(validEnvironmentName: "staging_1")
        try verify(validEnvironmentName: "production")
        try verify(validEnvironmentName: "production:some")
        try verify(validEnvironmentName: "pro/d-uct.ion_")

        verify(invalidEnvironmentName: "")
        verify(invalidEnvironmentName: "*^@!&#")
        verify(invalidEnvironmentName: "abc def")
        verify(invalidEnvironmentName: "*^@!&#")
        verify(invalidEnvironmentName: "*^@!&#\nsome_env")
        verify(invalidEnvironmentName: String(repeating: "a", count: 197))
    }

    func testPerformance() throws {
        let iOSAppConfiguration = try FeaturesConfiguration(
            configuration: .mockAny(), appContext: .mockWith(bundleType: .iOSApp)
        )
        XCTAssertEqual(iOSAppConfiguration.common.performance, .lowRuntimeImpact)

        let iOSAppExtensionConfiguration = try FeaturesConfiguration(
            configuration: .mockAny(), appContext: .mockWith(bundleType: .iOSAppExtension)
        )
        XCTAssertEqual(iOSAppExtensionConfiguration.common.performance, .instantDataDelivery)
    }

    func testEndpoint() throws {
        let clientToken: String = .mockRandom(among: "abcdef")
        let randomLogsEndpoint: Datadog.Configuration.LogsEndpoint = .mockRandom()
        let randomTracesEndpoint: Datadog.Configuration.TracesEndpoint = .mockRandom()
        let randomRUMEndpoint: Datadog.Configuration.RUMEndpoint = .mockRandom()

        func configuration(datadogEndpoint: Datadog.Configuration.DatadogEndpoint?) throws -> FeaturesConfiguration {
            try createConfiguration(
                clientToken: clientToken,
                datadogEndpoint: datadogEndpoint,
                logsEndpoint: randomLogsEndpoint,
                tracesEndpoint: randomTracesEndpoint,
                rumEndpoint: randomRUMEndpoint
            )
        }

        XCTAssertEqual(
            try configuration(datadogEndpoint: .us).logging?.uploadURLWithClientToken.absoluteString,
            "https://mobile-http-intake.logs.datadoghq.com/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .eu).logging?.uploadURLWithClientToken.absoluteString,
            "https://mobile-http-intake.logs.datadoghq.eu/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .gov).logging?.uploadURLWithClientToken.absoluteString,
            "https://mobile-http-intake.logs.ddog-gov.com/v1/input/" + clientToken
        )

        XCTAssertEqual(
            try configuration(datadogEndpoint: .us).tracing?.uploadURLWithClientToken.absoluteString,
            "https://public-trace-http-intake.logs.datadoghq.com/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .eu).tracing?.uploadURLWithClientToken.absoluteString,
            "https://public-trace-http-intake.logs.datadoghq.eu/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .gov).tracing?.uploadURLWithClientToken.absoluteString,
            "https://public-trace-http-intake.logs.ddog-gov.com/v1/input/" + clientToken
        )

        XCTAssertEqual(
            try configuration(datadogEndpoint: .us).rum?.uploadURLWithClientToken.absoluteString,
            "https://rum-http-intake.logs.datadoghq.com/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .eu).rum?.uploadURLWithClientToken.absoluteString,
            "https://rum-http-intake.logs.datadoghq.eu/v1/input/" + clientToken
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: .gov).rum?.uploadURLWithClientToken.absoluteString,
            "https://rum-http-intake.logs.ddog-gov.com/v1/input/" + clientToken
        )

        XCTAssertEqual(
            try configuration(datadogEndpoint: nil).logging?.uploadURLWithClientToken.absoluteString,
            randomLogsEndpoint.url + clientToken,
            "When `DatadogEndpoint` is not set, it should default to `LogsEndpoint` value."
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: nil).tracing?.uploadURLWithClientToken.absoluteString,
            randomTracesEndpoint.url + clientToken,
            "When `DatadogEndpoint` is not set, it should default to `TracesEndpoint` value."
        )
        XCTAssertEqual(
            try configuration(datadogEndpoint: nil).rum?.uploadURLWithClientToken.absoluteString,
            randomRUMEndpoint.url + clientToken,
            "When `DatadogEndpoint` is not set, it should default to `RUMEndpoint` value."
        )
    }

    // MARK: - Logging Configuration Tests

    func testWhenLoggingIsDisabled() throws {
        XCTAssertNil(
            try FeaturesConfiguration(configuration: .mockWith(loggingEnabled: false), appContext: .mockAny()).logging,
            "Feature configuration should not be available if the feature is disabled"
        )
    }

    func testCustomLogsEndpoint() throws {
        let clientToken: String = .mockRandom(among: "abcdef")
        let randomDatadogEndpoint: Datadog.Configuration.DatadogEndpoint = .mockRandom()
        let randomCustomEndpoint: URL = .mockRandom()

        let configuration = try createConfiguration(
            clientToken: clientToken,
            datadogEndpoint: randomDatadogEndpoint,
            customLogsEndpoint: randomCustomEndpoint
        )

        XCTAssertEqual(
            configuration.logging?.uploadURLWithClientToken,
            randomCustomEndpoint.appendingPathComponent(clientToken),
            "When custom endpoint is set it shuold override `DatadogEndpoint`"
        )
    }

    // MARK: - Tracing Configuration Tests

    func testWhenTracingIsDisabled() throws {
        XCTAssertNil(
            try FeaturesConfiguration(configuration: .mockWith(tracingEnabled: false), appContext: .mockAny()).tracing,
            "Feature configuration should not be available if the feature is disabled"
        )
    }

    func testCustomTracesEndpoint() throws {
        let clientToken: String = .mockRandom(among: "abcdef")
        let randomDatadogEndpoint: Datadog.Configuration.DatadogEndpoint = .mockRandom()
        let randomCustomEndpoint: URL = .mockRandom()

        let configuration = try createConfiguration(
            clientToken: clientToken,
            datadogEndpoint: randomDatadogEndpoint,
            customTracesEndpoint: randomCustomEndpoint
        )

        XCTAssertEqual(
            configuration.tracing?.uploadURLWithClientToken,
            randomCustomEndpoint.appendingPathComponent(clientToken),
            "When custom endpoint is set it shuold override `DatadogEndpoint`"
        )
    }

    // MARK: - RUM Configuration Tests

    func testWhenRUMIsDisabled() throws {
        XCTAssertNil(
            try FeaturesConfiguration(configuration: .mockWith(rumEnabled: false), appContext: .mockAny()).rum,
            "Feature configuration should not be available if the feature is disabled"
        )
    }

    func testCustomRUMEndpoint() throws {
        let clientToken: String = .mockRandom(among: "abcdef")
        let randomDatadogEndpoint: Datadog.Configuration.DatadogEndpoint = .mockRandom()
        let randomCustomEndpoint: URL = .mockRandom()

        let configuration = try createConfiguration(
            clientToken: clientToken,
            datadogEndpoint: randomDatadogEndpoint,
            customRUMEndpoint: randomCustomEndpoint
        )

        XCTAssertEqual(
            configuration.rum?.uploadURLWithClientToken,
            randomCustomEndpoint.appendingPathComponent(clientToken),
            "When custom endpoint is set it shuold override `DatadogEndpoint`"
        )
    }

    func testRUMSamplingRate() throws {
        let custom = try FeaturesConfiguration(
            configuration: .mockWith(
                rumApplicationID: "rum-app-id",
                rumEnabled: true,
                rumSessionsSamplingRate: 45.2
            ),
            appContext: .mockAny()
        )
        XCTAssertEqual(custom.rum?.applicationID, "rum-app-id")
        XCTAssertEqual(custom.rum?.sessionSamplingRate, 45.2)
    }

    func testRUMAutoInstrumentationConfiguration() throws {
        let viewsConfigured = try FeaturesConfiguration(
            configuration: .mockWith(
                rumEnabled: true,
                rumUIKitViewsPredicate: UIKitRUMViewsPredicateMock(),
                rumUIKitActionsTrackingEnabled: false
            ),
            appContext: .mockAny()
        )
        XCTAssertNotNil(viewsConfigured.rum!.autoInstrumentation!.uiKitRUMViewsPredicate)
        XCTAssertFalse(viewsConfigured.rum!.autoInstrumentation!.uiKitActionsTrackingEnabled)

        let actionsConfigured = try FeaturesConfiguration(
            configuration: .mockWith(
                rumEnabled: true,
                rumUIKitViewsPredicate: nil,
                rumUIKitActionsTrackingEnabled: true
            ),
            appContext: .mockAny()
        )
        XCTAssertNil(actionsConfigured.rum!.autoInstrumentation!.uiKitRUMViewsPredicate)
        XCTAssertTrue(actionsConfigured.rum!.autoInstrumentation!.uiKitActionsTrackingEnabled)

        let viewsAndActionsNotConfigured = try FeaturesConfiguration(
            configuration: .mockWith(
                rumEnabled: true,
                rumUIKitViewsPredicate: nil,
                rumUIKitActionsTrackingEnabled: false
            ),
            appContext: .mockAny()
        )
        XCTAssertNil(
            viewsAndActionsNotConfigured.rum!.autoInstrumentation,
            "When neither Views nor Actions are configured, the auto instrumentation config shuld be `nil`"
        )
    }

    // MARK: - URLSession Auto Instrumentation Configuration Tests

    func testURLSessionAutoInstrumentationConfiguration() throws {
        let randomDatadogEndpoint: Datadog.Configuration.DatadogEndpoint = .mockRandom()
        let randomCustomLogsEndpoint: URL? = Bool.random() ? .mockRandom() : nil
        let randomCustomTracesEndpoint: URL? = Bool.random() ? .mockRandom() : nil
        let randomCustomRUMEndpoint: URL? = Bool.random() ? .mockRandom() : nil

        let firstPartyHosts: Set<String> = ["example.com", "foo.eu"]
        let expectedSDKInternalURLs: Set<String> = [
            randomCustomLogsEndpoint?.absoluteString ?? randomDatadogEndpoint.logsEndpoint.url,
            randomCustomTracesEndpoint?.absoluteString ?? randomDatadogEndpoint.tracesEndpoint.url,
            randomCustomRUMEndpoint?.absoluteString ?? randomDatadogEndpoint.rumEndpoint.url
        ]

        func createConfiguration(
            tracingEnabled: Bool,
            rumEnabled: Bool,
            firstPartyHosts: Set<String>?
        ) throws -> FeaturesConfiguration {
            try FeaturesConfiguration(
                configuration: .mockWith(
                    tracingEnabled: tracingEnabled,
                    rumEnabled: rumEnabled,
                    datadogEndpoint: randomDatadogEndpoint,
                    customLogsEndpoint: randomCustomLogsEndpoint,
                    customTracesEndpoint: randomCustomTracesEndpoint,
                    customRUMEndpoint: randomCustomRUMEndpoint,
                    firstPartyHosts: firstPartyHosts
                ),
                appContext: .mockAny()
            )
        }

        // When `firstPartyHosts` are provided and both Tracing and RUM are enabled
        var configuration = try createConfiguration(
            tracingEnabled: true,
            rumEnabled: true,
            firstPartyHosts: firstPartyHosts
        )
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.userDefinedFirstPartyHosts, firstPartyHosts)
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.sdkInternalURLs, expectedSDKInternalURLs)
        XCTAssertTrue(configuration.urlSessionAutoInstrumentation!.instrumentTracing)
        XCTAssertTrue(configuration.urlSessionAutoInstrumentation!.instrumentRUM)

        // When `firstPartyHosts` are set and only Tracing is enabled
        configuration = try createConfiguration(
            tracingEnabled: true,
            rumEnabled: false,
            firstPartyHosts: firstPartyHosts
        )
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.userDefinedFirstPartyHosts, firstPartyHosts)
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.sdkInternalURLs, expectedSDKInternalURLs)
        XCTAssertTrue(configuration.urlSessionAutoInstrumentation!.instrumentTracing)
        XCTAssertFalse(configuration.urlSessionAutoInstrumentation!.instrumentRUM)

        // When `firstPartyHosts` are set and only RUM is enabled
        configuration = try createConfiguration(
            tracingEnabled: false,
            rumEnabled: true,
            firstPartyHosts: firstPartyHosts
        )
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.userDefinedFirstPartyHosts, firstPartyHosts)
        XCTAssertEqual(configuration.urlSessionAutoInstrumentation?.sdkInternalURLs, expectedSDKInternalURLs)
        XCTAssertFalse(configuration.urlSessionAutoInstrumentation!.instrumentTracing)
        XCTAssertTrue(configuration.urlSessionAutoInstrumentation!.instrumentRUM)

        // When `firstPartyHosts` are not set
        configuration = try createConfiguration(
            tracingEnabled: true,
            rumEnabled: true,
            firstPartyHosts: nil
        )
        XCTAssertNil(
            configuration.urlSessionAutoInstrumentation,
            "When `firstPartyHosts` are not set, the URLSession auto instrumentation config shuld be `nil`"
        )

        // When `firstPartyHosts` are set empty
        configuration = try createConfiguration(
            tracingEnabled: true,
            rumEnabled: true,
            firstPartyHosts: []
        )
        XCTAssertNil(
            configuration.urlSessionAutoInstrumentation,
            "When `firstPartyHosts` are set empty, the URLSession auto instrumentation config shuld be `nil`"
        )
    }

    // MARK: - Invalid Configurations

    func testWhenClientTokenIsInvalid_itThrowsProgrammerError() {
        XCTAssertThrowsError(try createConfiguration(clientToken: "")) { error in
            XCTAssertEqual((error as? ProgrammerError)?.description, "🔥 Datadog SDK usage error: `clientToken` cannot be empty.")
        }
    }

    func testWhenCustomEndpointIsInvalid_itThrowsProgrammerError() {
        XCTAssertThrowsError(try createConfiguration(logsEndpoint: .custom(url: "not a valid url string"))) { error in
            XCTAssertEqual(
                (error as? ProgrammerError)?.description,
                "🔥 Datadog SDK usage error: The `url` in `.custom(url:)` must be a valid URL string."
            )
        }
    }

    func testGivenNoRUMApplicationIDProvided_whenRUMFeatureIsEnabled_itPrintsConsoleWarning() throws {
        let printFunction = PrintFunctionMock()
        consolePrint = printFunction.print
        defer { consolePrint = { print($0) } }

        _ = try FeaturesConfiguration(
            configuration: .mockWith(rumApplicationID: nil, rumEnabled: true),
            appContext: .mockAny()
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            """
            🔥 Datadog SDK usage error: In order to use the RUM feature, `Datadog.Configuration` must be constructed using:
            `.builderUsing(rumApplicationID:rumClientToken:environment:)`
            """
        )
    }

    func testGivenFirstPartyHostsDefined_whenRUMAndTracingAreDisabled_itDoesNotInstrumentURLSessionAndPrintsConsoleWarning() throws {
        let printFunction = PrintFunctionMock()
        consolePrint = printFunction.print
        defer { consolePrint = { print($0) } }

        // Given
        let firstPartyHosts: Set<String> = ["first-party.com"]

        // When
        let tracingEnabled = false
        let rumEnabled = false

        // Then
        let configuration = try FeaturesConfiguration(
            configuration: .mockWith(tracingEnabled: tracingEnabled, rumEnabled: rumEnabled, firstPartyHosts: firstPartyHosts),
            appContext: .mockAny()
        )

        XCTAssertNil(
            configuration.urlSessionAutoInstrumentation,
            "`URLSession` should not be auto instrumented."
        )

        XCTAssertEqual(
            printFunction.printedMessage,
            """
            🔥 Datadog SDK usage error: To use `.track(firstPartyHosts:)` either RUM or Tracing should be enabled.
            """
        )
    }

    // MARK: - Helpers

    private func createConfiguration(
        clientToken: String = "abc",
        datadogEndpoint: Datadog.Configuration.DatadogEndpoint? = nil,
        customLogsEndpoint: URL? = nil,
        customTracesEndpoint: URL? = nil,
        customRUMEndpoint: URL? = nil,
        logsEndpoint: Datadog.Configuration.LogsEndpoint = .us,
        tracesEndpoint: Datadog.Configuration.TracesEndpoint = .us,
        rumEndpoint: Datadog.Configuration.RUMEndpoint = .us
    ) throws -> FeaturesConfiguration {
        return try FeaturesConfiguration(
            configuration: .mockWith(
                clientToken: clientToken,
                loggingEnabled: true,
                tracingEnabled: true,
                rumEnabled: true,
                datadogEndpoint: datadogEndpoint,
                customLogsEndpoint: customLogsEndpoint,
                customTracesEndpoint: customTracesEndpoint,
                customRUMEndpoint: customRUMEndpoint,
                logsEndpoint: logsEndpoint,
                tracesEndpoint: tracesEndpoint,
                rumEndpoint: rumEndpoint
            ),
            appContext: .mockAny()
        )
    }
}

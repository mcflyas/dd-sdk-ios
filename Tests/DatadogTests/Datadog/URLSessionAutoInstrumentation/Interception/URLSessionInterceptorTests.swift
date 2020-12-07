/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

private class URLSessionInterceptionHandlerMock: URLSessionInterceptionHandler {
    var didNotifyInterceptionStart: ((TaskInterception) -> Void)?
    var startedInterceptions: [TaskInterception] = []

    func notify_taskInterceptionStarted(interception: TaskInterception) {
        startedInterceptions.append(interception)
        didNotifyInterceptionStart?(interception)
    }

    var didNotifyInterceptionCompletion: ((TaskInterception) -> Void)?
    var completedInterceptions: [TaskInterception] = []

    func notify_taskInterceptionCompleted(interception: TaskInterception) {
        completedInterceptions.append(interception)
        didNotifyInterceptionCompletion?(interception)
    }
}

class URLSessionInterceptorTests: XCTestCase {
    private let handler = URLSessionInterceptionHandlerMock()
    /// Mock request made to a first party URL.
    private let firstPartyRequest = URLRequest(url: URL(string: "https://api.first-party.com/v1/endpoint")!)
    /// Mock request made to a third party URL.
    private let thirdPartyRequest = URLRequest(url: URL(string: "https://api.third-party.com/v1/endpoint")!)
    /// Mock request made internally by the SDK (used to test that SDK internal calls to Intake servers are not intercepted).
    private let internalRequest = URLRequest(url: URL(string: "https://dd.internal.com/v1/endpoint")!)

    // MARK: - Initialization

    func testGivenOnlyTracingInstrumentationEnabled_whenInitializing_itRegistersTracingHandler() {
        // Given
        let instrumentTracing = true
        let instrumentRUM = false

        // When
        let interceptor = URLSessionInterceptor(
            configuration: .mockWith(instrumentTracing: instrumentTracing, instrumentRUM: instrumentRUM),
            dateProvider: SystemDateProvider()
        )

        // Then
        XCTAssertTrue(interceptor.handler is URLSessionTracingHandler)
        XCTAssertTrue(
            interceptor.injectTracingHeadersToFirstPartyRequests,
            "Tracing headers should be injected when only Tracing instrumentation is enabled."
        )
        XCTAssertNil(
            interceptor.additionalHeadersForFirstPartyRequests,
            "Just the tracing headers should be injected when only Tracing instrumentation is enabled."
        )
    }

    func testGivenOnlyRUMInstrumentationEnabled_whenInitializing_itRegistersRUMHandler() {
        // Given
        let instrumentTracing = false
        let instrumentRUM = true

        // When
        let interceptor = URLSessionInterceptor(
            configuration: .mockWith(instrumentTracing: instrumentTracing, instrumentRUM: instrumentRUM),
            dateProvider: SystemDateProvider()
        )

        // Then
        XCTAssertTrue(interceptor.handler is URLSessionRUMResourcesHandler)
        XCTAssertFalse(
            interceptor.injectTracingHeadersToFirstPartyRequests,
            "Tracing headers should not be injected when only RUM instrumentation is enabled."
        )
        XCTAssertNil(
            interceptor.additionalHeadersForFirstPartyRequests,
            "No additional headers should be injected when only RUM instrumentation is enabled."
        )
    }

    func testGivenBothTracingAndRUMInstrumentationEnabled_whenInitializing_itRegistersRUMHandler() {
        // Given
        let instrumentTracing = true
        let instrumentRUM = true

        // When
        let interceptor = URLSessionInterceptor(
            configuration: .mockWith(instrumentTracing: instrumentTracing, instrumentRUM: instrumentRUM),
            dateProvider: SystemDateProvider()
        )

        // Then
        XCTAssertTrue(interceptor.handler is URLSessionRUMResourcesHandler)
        XCTAssertTrue(
            interceptor.injectTracingHeadersToFirstPartyRequests,
            "Tracing headers should be injected when both Tracing and RUM instrumentations are enabled."
        )
        XCTAssertEqual(
            interceptor.additionalHeadersForFirstPartyRequests,
            [TracingHTTPHeaders.originField: TracingHTTPHeaders.rumOriginValue],
            "Additional `x-datadog-origin: rum` header should be injected when both Tracing and RUM instrumentations are enabled."
        )
    }

    // MARK: - URLRequest Interception

    private func mockConfiguration(
        tracingInstrumentationEnabled: Bool,
        rumInstrumentationEnabled: Bool
    ) -> FeaturesConfiguration.URLSessionAutoInstrumentation {
        return .mockWith(
            userDefinedFirstPartyHosts: ["first-party.com"],
            sdkInternalURLs: ["https://dd.internal.com"],
            instrumentTracing: tracingInstrumentationEnabled,
            instrumentRUM: rumInstrumentationEnabled
        )
    }

    func testGivenTracingAndRUMInstrumentationEnabled_whenInterceptingRequests_itInjectsTracingContextToFirstPartyRequests() throws {
        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: true, rumInstrumentationEnabled: true),
            handler: handler
        )
        GlobalDatadog.sharedTracer = Tracer.mockAny()
        defer { GlobalDatadog.sharedTracer = DDNoopGlobals.tracer }

        // When
        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // Then
        XCTAssertNotNil(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.traceIDField])
        XCTAssertNotNil(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.parentSpanIDField])
        XCTAssertEqual(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.originField], TracingHTTPHeaders.rumOriginValue)
        assertRequestsEqual(
            interceptedFirstPartyRequest
                .removing(httpHeaderField: TracingHTTPHeaders.traceIDField)
                .removing(httpHeaderField: TracingHTTPHeaders.parentSpanIDField)
                .removing(httpHeaderField: TracingHTTPHeaders.originField),
            firstPartyRequest,
            "The only modification of the original requests should be the addition of 3 tracing headers."
        )
        assertRequestsEqual(thirdPartyRequest, interceptedThirdPartyRequest, "Intercepted 3rd party request should not be modified.")
        assertRequestsEqual(internalRequest, interceptedInternalRequest, "Intercepted internal request should not be modified.")
    }

    func testGivenOnlyTracingInstrumentationEnabled_whenInterceptingRequests_itInjectsTracingContextToFirstPartyRequests() throws {
        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: true, rumInstrumentationEnabled: false),
            handler: handler
        )
        GlobalDatadog.sharedTracer = Tracer.mockAny()
        defer { GlobalDatadog.sharedTracer = DDNoopGlobals.tracer }

        // When
        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // Then
        XCTAssertNotNil(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.traceIDField])
        XCTAssertNotNil(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.parentSpanIDField])
        XCTAssertNil(interceptedFirstPartyRequest.allHTTPHeaderFields?[TracingHTTPHeaders.originField], "Origin header should not be added if RUM is disabled.")
        assertRequestsEqual(
            interceptedFirstPartyRequest
                .removing(httpHeaderField: TracingHTTPHeaders.traceIDField)
                .removing(httpHeaderField: TracingHTTPHeaders.parentSpanIDField),
            firstPartyRequest,
            "The only modification of the original requests should be the addition of 2 tracing headers."
        )
        assertRequestsEqual(thirdPartyRequest, interceptedThirdPartyRequest, "Intercepted 3rd party request should not be modified.")
        assertRequestsEqual(internalRequest, interceptedInternalRequest, "Intercepted internal request should not be modified.")
    }

    func testGivenOnlyRUMInstrumentationEnabled_whenInterceptingRequests_itDoesNotModifyThem() throws {
        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: false, rumInstrumentationEnabled: true),
            handler: handler
        )
        GlobalDatadog.sharedTracer = Tracer.mockAny()
        defer { GlobalDatadog.sharedTracer = DDNoopGlobals.tracer }

        // When
        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // Then
        assertRequestsEqual(firstPartyRequest, interceptedFirstPartyRequest, "Intercepted 1st party request should not be modified.")
        assertRequestsEqual(thirdPartyRequest, interceptedThirdPartyRequest, "Intercepted 3rd party request should not be modified.")
        assertRequestsEqual(internalRequest, interceptedInternalRequest, "Intercepted internal request should not be modified.")
    }

    func testGivenTracingInstrumentationEnabledButTracerNotRegistered_whenInterceptingRequests_itDoesNotInjectTracingContextToAnyRequest() throws {
        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: true, rumInstrumentationEnabled: .random()),
            handler: handler
        )
        XCTAssertTrue(GlobalDatadog.sharedTracer is DDNoopTracer)

        // When
        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // Then
        assertRequestsEqual(firstPartyRequest, interceptedFirstPartyRequest, "Intercepted 1st party request should not be modified.")
        assertRequestsEqual(thirdPartyRequest, interceptedThirdPartyRequest, "Intercepted 3rd party request should not be modified.")
        assertRequestsEqual(internalRequest, interceptedInternalRequest, "Intercepted internal request should not be modified.")
    }

    // MARK: - URLSessionTask Interception

    func testGivenTracingInstrumentationEnabled_whenInterceptingURLSessionTasks_itNotifiesStartAndCompletion() throws {
        let interceptionStartedExpectation = expectation(description: "Start task interception")
        interceptionStartedExpectation.expectedFulfillmentCount = 2
        handler.didNotifyInterceptionStart = { interception in
            XCTAssertFalse(interception.isDone)
            interceptionStartedExpectation.fulfill()
        }

        let interceptionCompletedExpectation = expectation(description: "Complete task interception")
        interceptionCompletedExpectation.expectedFulfillmentCount = 2
        handler.didNotifyInterceptionCompletion = { interception in
            XCTAssertTrue(interception.isDone)
            interceptionCompletedExpectation.fulfill()
        }

        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: true, rumInstrumentationEnabled: .random()),
            handler: handler
        )
        GlobalDatadog.sharedTracer = Tracer.mockAny()
        defer { GlobalDatadog.sharedTracer = DDNoopGlobals.tracer }

        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // When
        let firstPartyTask: URLSessionTask = .mockWith(request: interceptedFirstPartyRequest, response: .mockAny())
        let thirdPartyTask: URLSessionTask = .mockWith(request: interceptedThirdPartyRequest, response: .mockAny())
        let internalTask: URLSessionTask = .mockWith(request: interceptedInternalRequest, response: .mockAny())

        // swiftlint:disable opening_brace
        callConcurrently(
            { interceptor.taskCreated(urlSession: .mockAny(), task: firstPartyTask) },
            { interceptor.taskCreated(urlSession: .mockAny(), task: thirdPartyTask) },
            { interceptor.taskCreated(urlSession: .mockAny(), task: internalTask) }
        )
        callConcurrently(
            { interceptor.taskCompleted(urlSession: .mockAny(), task: firstPartyTask, error: nil) },
            { interceptor.taskCompleted(urlSession: .mockAny(), task: thirdPartyTask, error: nil) },
            { interceptor.taskCompleted(urlSession: .mockAny(), task: internalTask, error: nil) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: firstPartyTask, metrics: .mockAny()) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: thirdPartyTask, metrics: .mockAny()) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: internalTask, metrics: .mockAny()) }
        )
        // swiftlint:enable opening_brace

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        // We compare `URLRequests` by their `.url` in following assertions
        // due to https://openradar.appspot.com/radar?id=4988276943355904

        let startedInterceptions = handler.startedInterceptions
        XCTAssertEqual(startedInterceptions.count, 2)
        XCTAssertTrue(
            startedInterceptions.contains { $0.request.url == firstPartyRequest.url && $0.spanContext != nil },
            "Interception should be started and span context should be set for 1st party request."
        )
        XCTAssertTrue(
            startedInterceptions.contains { $0.request.url == thirdPartyRequest.url && $0.spanContext == nil },
            "Interception should be started but span context should NOT be set for 3rd party request."
        )

        let completedInterceptions = handler.completedInterceptions
        XCTAssertEqual(completedInterceptions.count, 2)
        XCTAssertTrue(
            completedInterceptions.contains { $0.request.url == firstPartyRequest.url && $0.spanContext != nil },
            "Interception should be completed and span context be set for 1st party request."
        )
        XCTAssertTrue(
            completedInterceptions.contains { $0.request.url == thirdPartyRequest.url && $0.spanContext == nil },
            "Interception should be completed but span context should NOT be set for 3rd party request."
        )
    }

    func testGivenOnlyRUMInstrumentationEnabled_whenInterceptingURLSessionTasks_itNotifiesStartAndCompletion() throws {
        let interceptionStartedExpectation = expectation(description: "Start task interception")
        interceptionStartedExpectation.expectedFulfillmentCount = 2
        handler.didNotifyInterceptionStart = { interception in
            XCTAssertFalse(interception.isDone)
            interceptionStartedExpectation.fulfill()
        }

        let interceptionCompletedExpectation = expectation(description: "Complete task interception")
        interceptionCompletedExpectation.expectedFulfillmentCount = 2
        handler.didNotifyInterceptionCompletion = { interception in
            XCTAssertTrue(interception.isDone)
            interceptionCompletedExpectation.fulfill()
        }

        // Given
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: false, rumInstrumentationEnabled: true),
            handler: handler
        )

        let interceptedFirstPartyRequest = interceptor.modify(request: firstPartyRequest)
        let interceptedThirdPartyRequest = interceptor.modify(request: thirdPartyRequest)
        let interceptedInternalRequest = interceptor.modify(request: internalRequest)

        // When
        let firstPartyTask: URLSessionTask = .mockWith(request: interceptedFirstPartyRequest, response: .mockAny())
        let thirdPartyTask: URLSessionTask = .mockWith(request: interceptedThirdPartyRequest, response: .mockAny())
        let internalTask: URLSessionTask = .mockWith(request: interceptedInternalRequest, response: .mockAny())

        // swiftlint:disable opening_brace
        callConcurrently(
            { interceptor.taskCreated(urlSession: .mockAny(), task: firstPartyTask) },
            { interceptor.taskCreated(urlSession: .mockAny(), task: thirdPartyTask) },
            { interceptor.taskCreated(urlSession: .mockAny(), task: internalTask) }
        )
        callConcurrently(
            { interceptor.taskCompleted(urlSession: .mockAny(), task: firstPartyTask, error: nil) },
            { interceptor.taskCompleted(urlSession: .mockAny(), task: thirdPartyTask, error: nil) },
            { interceptor.taskCompleted(urlSession: .mockAny(), task: internalTask, error: nil) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: firstPartyTask, metrics: .mockAny()) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: thirdPartyTask, metrics: .mockAny()) },
            { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: internalTask, metrics: .mockAny()) }
        )
        // swiftlint:enable opening_brace

        // Then
        waitForExpectations(timeout: 0.25, handler: nil)

        // We compare `URLRequests` by their `.url` in following assertions
        // due to https://openradar.appspot.com/radar?id=4988276943355904

        let startedInterceptions = handler.startedInterceptions
        XCTAssertEqual(startedInterceptions.count, 2)
        XCTAssertTrue(
            startedInterceptions.contains { $0.request.url == firstPartyRequest.url && $0.spanContext == nil },
            "Interception should be started but span context should NOT be set for 1st party request."
        )
        XCTAssertTrue(
            startedInterceptions.contains { $0.request.url == thirdPartyRequest.url && $0.spanContext == nil },
            "Interception should be started but span context should NOT be set for 3rd party request."
        )

        let completedInterceptions = handler.completedInterceptions
        XCTAssertEqual(completedInterceptions.count, 2)
        XCTAssertTrue(
            completedInterceptions.contains { $0.request.url == firstPartyRequest.url && $0.spanContext == nil },
            "Interception should be completed but span context should NOT be set for 1st party request."
        )
        XCTAssertTrue(
            completedInterceptions.contains { $0.request.url == thirdPartyRequest.url && $0.spanContext == nil },
            "Interception should be completed but span context should NOT be set for 3rd party request."
        )
    }

    // MARK: - Thread Safety

    func testRandomlyCallingDifferentAPIsConcurrentlyDoesNotCrash() {
        let interceptor = URLSessionInterceptor(
            configuration: mockConfiguration(tracingInstrumentationEnabled: true, rumInstrumentationEnabled: true),
            handler: handler
        )

        let requests = [firstPartyRequest, thirdPartyRequest, internalRequest]
        let tasks = (0..<10).map { _ in URLSessionTask.mockWith(request: .mockAny(), response: .mockAny()) }

        // swiftlint:disable opening_brace
        callConcurrently(
            closures: [
                { _ = interceptor.modify(request: requests.randomElement()!) },
                { interceptor.taskCreated(urlSession: .mockAny(), task: tasks.randomElement()!) },
                { interceptor.taskMetricsCollected(urlSession: .mockAny(), task: tasks.randomElement()!, metrics: .mockAny()) },
                { interceptor.taskCompleted(urlSession: .mockAny(), task: tasks.randomElement()!, error: nil) }
            ],
            iterations: 50
        )
        // swiftlint:enable opening_brace
    }

    // MARK: - Helpers

    /// Because of https://openradar.appspot.com/radar?id=4988276943355904
    /// it is not always reliable to compare `URLRequests` using in-build equality operator (`r1 == r2`).
    /// This method implements a workaround by comparing request HTTP headers before checking equality.
    private func assertRequestsEqual(
        _ request1: URLRequest,
        _ request2: URLRequest,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let headers1 = request1.allHTTPHeaderFields ?? [:]
        let headers2 = request2.allHTTPHeaderFields ?? [:]
        XCTAssertEqual(headers1, headers2, message, file: file, line: line)
        XCTAssertEqual(request1, request2, message, file: file, line: line)
    }
}

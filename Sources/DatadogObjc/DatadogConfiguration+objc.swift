/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import class Datadog.Datadog

@objcMembers
public class DDEndpoint: NSObject {
    internal let sdkEndpoint: Datadog.Configuration.DatadogEndpoint

    internal init(sdkEndpoint: Datadog.Configuration.DatadogEndpoint) {
        self.sdkEndpoint = sdkEndpoint
    }

    // MARK: - Public

    public static func eu() -> DDEndpoint { .init(sdkEndpoint: .eu) }
    public static func us() -> DDEndpoint { .init(sdkEndpoint: .us) }
    public static func gov() -> DDEndpoint { .init(sdkEndpoint: .gov) }
}

@objcMembers
public class DDLogsEndpoint: NSObject {
    internal let sdkEndpoint: Datadog.Configuration.LogsEndpoint

    internal init(sdkEndpoint: Datadog.Configuration.LogsEndpoint) {
        self.sdkEndpoint = sdkEndpoint
    }

    // MARK: - Public

    public static func eu() -> DDLogsEndpoint { .init(sdkEndpoint: .eu) }
    public static func us() -> DDLogsEndpoint { .init(sdkEndpoint: .us) }
    public static func gov() -> DDLogsEndpoint { .init(sdkEndpoint: .gov) }
    public static func custom(url: String) -> DDLogsEndpoint { .init(sdkEndpoint: .custom(url: url)) }
}

@objcMembers
public class DDTracesEndpoint: NSObject {
    internal let sdkEndpoint: Datadog.Configuration.TracesEndpoint

    internal init(sdkEndpoint: Datadog.Configuration.TracesEndpoint) {
        self.sdkEndpoint = sdkEndpoint
    }

    // MARK: - Public

    public static func eu() -> DDTracesEndpoint { .init(sdkEndpoint: .eu) }
    public static func us() -> DDTracesEndpoint { .init(sdkEndpoint: .us) }
    public static func gov() -> DDTracesEndpoint { .init(sdkEndpoint: .gov) }
    public static func custom(url: String) -> DDTracesEndpoint { .init(sdkEndpoint: .custom(url: url)) }
}

@objcMembers
public class DDConfiguration: NSObject {
    internal let sdkConfiguration: Datadog.Configuration

    internal init(sdkConfiguration: Datadog.Configuration) {
        self.sdkConfiguration = sdkConfiguration
    }

    // MARK: - Public

    public static func builder(clientToken: String, environment: String) -> DDConfigurationBuilder {
        return DDConfigurationBuilder(
            sdkBuilder: Datadog.Configuration.builderUsing(clientToken: clientToken, environment: environment)
        )
    }
}

@objcMembers
public class DDConfigurationBuilder: NSObject {
    internal let sdkBuilder: Datadog.Configuration.Builder

    internal init(sdkBuilder: Datadog.Configuration.Builder) {
        self.sdkBuilder = sdkBuilder
    }

    // MARK: - Public

    public func enableLogging(_ enabled: Bool) {
        _ = sdkBuilder.enableLogging(enabled)
    }

    public func enableTracing(_ enabled: Bool) {
        _ = sdkBuilder.enableTracing(enabled)
    }

    public func set(endpoint: DDEndpoint) {
        _ = sdkBuilder.set(endpoint: endpoint.sdkEndpoint)
    }

    public func set(customLogsEndpoint: URL) {
        _ = sdkBuilder.set(customLogsEndpoint: customLogsEndpoint)
    }

    public func set(customTracesEndpoint: URL) {
        _ = sdkBuilder.set(customTracesEndpoint: customTracesEndpoint)
    }

    @available(*, deprecated, message: "This option is replaced by `set(endpoint:)`. Refer to the new API comment for details.")
    public func set(logsEndpoint: DDLogsEndpoint) {
        _ = sdkBuilder.set(logsEndpoint: logsEndpoint.sdkEndpoint)
    }

    @available(*, deprecated, message: "This option is replaced by `set(endpoint:)`. Refer to the new API comment for details.")
    public func set(tracesEndpoint: DDTracesEndpoint) {
        _ = sdkBuilder.set(tracesEndpoint: tracesEndpoint.sdkEndpoint)
    }

    @available(*, deprecated, message: "This option is replaced by `track(firstPartyHosts:)`. Refer to the new API comment for important details.")
    public func set(tracedHosts: Set<String>) {
        track(firstPartyHosts: tracedHosts)
    }

    public func track(firstPartyHosts: Set<String>) {
        _ = sdkBuilder.track(firstPartyHosts: firstPartyHosts)
    }

    public func set(serviceName: String) {
        _ = sdkBuilder.set(serviceName: serviceName)
    }

    public func build() -> DDConfiguration {
        return DDConfiguration(sdkConfiguration: sdkBuilder.build())
    }
}

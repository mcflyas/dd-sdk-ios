/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Builds `Span` representation (for later serialization) from `DDSpan`.
internal struct SpanBuilder {
    /// App information context.
    let appContext: AppContext
    /// Service name to encode in span.
    let serviceName: String
    /// Shared user info provider.
    let userInfoProvider: UserInfoProvider
    /// Shared network connection info provider.
    let networkConnectionInfoProvider: NetworkConnectionInfoProviderType
    /// Shared mobile carrier info provider.
    let carrierInfoProvider: CarrierInfoProviderType

    func createSpan(from ddspan: DDSpan, finishTime: Date) throws -> Span {
        guard let context = ddspan.context.dd else {
            throw InternalError(description: "`SpanBuilder` inconsistency - unrecognized span context.")
        }

        return Span(
            traceID: context.traceID,
            spanID: context.spanID,
            parentID: context.parentSpanID,
            operationName: ddspan.operationName,
            serviceName: serviceName,
            resource: ddspan.operationName, // TODO: RUMM-400 use `resourceName`: `resource: ddspan.resourceName ?? ddspan.operationName`
            startTime: ddspan.startTime,
            duration: finishTime.timeIntervalSince(ddspan.startTime),
            isError: false, // TODO: RUMM-401 use error flag from `ddspan`
            tracerVersion: sdkVersion,
            applicationVersion: getApplicationVersion(),
            networkConnectionInfo: networkConnectionInfoProvider.current,
            mobileCarrierInfo: carrierInfoProvider.current,
            userInfo: userInfoProvider.value
        )
    }

    // TODO: RUMM-299 Consider sharing `getApplicationVersion` between `SpanBuilder` and `LogBuilder` when tests are ready
    private func getApplicationVersion() -> String {
        if let shortVersion = appContext.bundleShortVersion {
            return shortVersion
        } else if let version = appContext.bundleVersion {
            return version
        } else {
            return ""
        }
    }
}
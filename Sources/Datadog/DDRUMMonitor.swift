/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit

/// A class enabling Datadog RUM features.
///
/// `DDRUMMonitor` allows you to record User events that can be explored and analyzed in Datadog Dashboards.
/// You can only have one active `RUMMonitor`, and should register/retrieve it from the `Global` object.
public class DDRUMMonitor {
    // MARK: - Public methods

    /// Notifies that the View starts being presented to the user.
    /// - Parameters:
    ///   - viewController: the instance of `UIViewController` representing this View.
    ///   - path: the View path used for RUM Explorer. If not provided, the `UIViewController` class name will be used.
    ///   - attributes: custom attributes to attach to the View.
    public func startView(
        viewController: UIViewController,
        path: String? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the View stops being presented to the user.
    /// - Parameters:
    ///   - viewController: the instance of `UIViewController` representing this View.
    ///   - attributes: custom attributes to attach to the View.
    public func stopView(
        viewController: UIViewController,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Adds a specific timing in the currently presented View. The timing duration will be computed as the
    /// number of nanoseconds between the time the View was started and the time the timing was added.
    /// - Parameters:
    ///   - name: the name of the custom timing attribute. It must be unique for each timing.
    public func addTiming(
        name: String
    ) {}

    /// Notifies that an Error occurred in currently presented View.
    /// - Parameters:
    ///   - message: a message explaining the Error.
    ///   - source: the origin of the error.
    ///   - attributes: custom attributes to attach to the Error
    ///   - file: the file in which the Error occurred (the default is the file name in which this method was called).
    ///   - line: the line number on which the Error occurred (the default is the line number on which this method was called).
    public func addError(
        message: String,
        source: RUMErrorSource = .custom,
        attributes: [AttributeKey: AttributeValue] = [:],
        file: StaticString? = #file,
        line: UInt? = #line
    ) {}

    /// Notifies that an Error occurred in currently presented View.
    /// - Parameters:
    ///   - error: the `Error` object. It will be used to build the Error description.
    ///   - source: the origin of the error.
    ///   - attributes: custom attributes to attach to the Error.
    public func addError(
        error: Error,
        source: RUMErrorSource = .custom,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the Resource starts being loaded.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must be unique among all Resources being currently loaded.
    ///   - request: the `URLRequest` for the Resource.
    ///   - attributes: custom attributes to attach to the Resource.
    public func startResourceLoading(
        resourceKey: String,
        request: URLRequest,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the Resource starts being loaded using GET request to given `url`.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must be unique among all Resources being currently loaded.
    ///   - url: the `URL` for the Resource.
    ///   - attributes: custom attributes to attach to the Resource.
    public func startResourceLoading(
        resourceKey: String,
        url: URL,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Adds temporal metrics to given Resource. This method must be called before the Resource is stopped.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must match the one used in `startResourceLoading(...)`.
    ///   - metrics: the `URLSessionTaskMetrics` retrieved for this Resource
    ///   - attributes: custom attributes to attach to the Resource.
    public func addResourceMetrics(
        resourceKey: String,
        metrics: URLSessionTaskMetrics,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the Resource stops being loaded succesfully.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must match the one used in `startResourceLoading(...)`.
    ///   - response: the `URLResepone` received for the Resource.
    ///   - size: an optional size of the data received for the Resource (in bytes). If not provided, the SDK will try to infer it from the "Content-Length" header of the `response`.
    ///   - attributes: custom attributes to attach to the Resource.
    public func stopResourceLoading(
        resourceKey: String,
        response: URLResponse,
        size: Int64? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the Resource stops being loaded with an error.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must match the one used in `startResourceLoading(...)`.
    ///   - error: the `Error` object received when loading the Resource.
    ///   - response: an optional `URLResepone` received for the Resource.
    ///   - attributes: custom attributes to attach to the Resource.
    public func stopResourceLoadingWithError(
        resourceKey: String,
        error: Error,
        response: URLResponse? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the Resource stops being loaded with an error.
    /// If an `Error` object is received upon Resource failure, `GlobalDatadog.rum.stopResourceLoadingWithError(..., error:, ...)` may be used for convenience.
    /// - Parameters:
    ///   - resourceKey: the key representing the Resource - must match the one used in `startResourceLoading(...)`.
    ///   - errorMessage: the message explaining the Resource failure.
    ///   - response: an optional `URLResepone` received for the Resource.
    ///   - attributes: custom attributes to attach to the Resource.
    public func stopResourceLoadingWithError(
        resourceKey: String,
        errorMessage: String,
        response: URLResponse? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the User Action has started.
    /// This is used to track long running user actions (e.g. "scroll").
    /// Such an User Action must be stopped with `stopUserAction(type:)`, and will be stopped automatically if it lasts for more than 10 seconds.
    /// - Parameters:
    ///   - type: the User Action type.
    ///   - name: the User Action name.
    ///   - attributes: custom attributes to attach to the User Action.
    public func startUserAction(
        type: RUMUserActionType,
        name: String,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Notifies that the User Action has stopped.
    /// This is used to stop tracking long running user actions (e.g. "scroll"), started with `startUserAction(type:)`.
    /// - Parameters:
    ///   - type: the User Action type.
    ///   - name: the User Action name. If `nil`, the `name` used in `startUserAction` will be effective.
    ///   - attributes: custom attributes to attach to the User Action.
    public func stopUserAction(
        type: RUMUserActionType,
        name: String? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    /// Registers the occurence of an User Action.
    /// This is used to track discrete User Actions (e.g. "tap").
    /// - Parameters:
    ///   - type: the User Action type.
    ///   - name: the User Action name.
    ///   - attributes: custom attributes to attach to the User Action.
    public func addUserAction(
        type: RUMUserActionType,
        name: String,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {}

    // MARK: - Attributes

    /// Adds a custom attribute to all future events sent by the RUM monitor.
    /// - Parameters:
    ///   - key: key for this attribute. See `AttributeKey` documentation for information about
    ///   nesting attribute values using dot `.` syntax.
    ///   - value: any value that conforms to `Encodable`. See `AttributeValue` documentation
    ///   for information about nested encoding containers limitation.
    public func addAttribute(forKey key: AttributeKey, value: AttributeValue) {}

    /// Removes the custom attribute from all future events sent by the RUM monitor.
    /// Events created prior to this call will not lose this attribute.
    /// - Parameter key: key for the attribute that will be removed.
    public func removeAttribute(forKey key: AttributeKey) {}

    // MARK: - Internal

    internal init() {}
}

/// The no-op variant of `DDRUMMonitor`.
internal class DDNoopRUMMonitor: DDRUMMonitor {
}

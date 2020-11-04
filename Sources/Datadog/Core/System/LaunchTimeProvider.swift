/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit
import _Datadog_Private

/// Provides the application launch time.
internal protocol LaunchTimeProviderType {
    /// The app process launch duration (in seconds) measured as the time from loading the first SDK object into memory
    /// to receiving `UIApplication.didBecomeActiveNotification` notification.
    var launchTime: TimeInterval? { get }
}

internal class LaunchTimeProvider: LaunchTimeProviderType {
    var launchTime: TimeInterval? {
        // Following dynamic dispatch synchronisation mutes TSAN issues when running tests from CLI.
        objc_sync_enter(self)
        let time = ObjcAppLaunchHandler.launchTime()
        objc_sync_exit(self)
        return time > 0 ? time : nil
    }
}

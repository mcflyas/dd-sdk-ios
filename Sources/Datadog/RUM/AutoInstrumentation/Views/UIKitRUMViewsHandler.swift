/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import UIKit

internal protocol UIKitRUMViewsHandlerType: class {
    func subscribe(commandsSubscriber: RUMCommandSubscriber)
    /// Gets called on `super.viewDidAppear()`.
    func notify_viewDidAppear(viewController: UIViewController, animated: Bool)
    /// Gets called on `super.viewDidDisappear()`.
    func notify_viewDidDisappear(viewController: UIViewController, animated: Bool)
}

internal class UIKitRUMViewsHandler: UIKitRUMViewsHandlerType {
    private let predicate: UIKitRUMViewsPredicate
    private let dateProvider: DateProvider
    private let inspector: UIKitHierarchyInspectorType

    init(
        predicate: UIKitRUMViewsPredicate,
        dateProvider: DateProvider,
        inspector: UIKitHierarchyInspectorType = UIKitHierarchyInspector()
    ) {
        self.predicate = predicate
        self.dateProvider = dateProvider
        self.inspector = inspector
    }

    // MARK: - UIKitRUMViewsHandlerType

    weak var subscriber: RUMCommandSubscriber?

    func subscribe(commandsSubscriber: RUMCommandSubscriber) {
        self.subscriber = commandsSubscriber
    }

    func notify_viewDidAppear(viewController: UIViewController, animated: Bool) {
        if let rumView = rumView(for: viewController) {
            startIfNotStarted(rumView: rumView, for: viewController)
        }
    }

    func notify_viewDidDisappear(viewController: UIViewController, animated: Bool) {
        if let topViewController = inspector.topViewController(),
           let rumView = rumView(for: topViewController) {
            startIfNotStarted(rumView: rumView, for: topViewController)
        }
    }

    // MARK: - Private

    /// The `UIViewController` recently asked in `UIKitRUMViewsPredicate`.
    private weak var recentlyAskedViewController: UIViewController?

    private func rumView(for viewController: UIViewController) -> RUMView? {
        if viewController === recentlyAskedViewController {
            return nil
        }

        recentlyAskedViewController = viewController
        return predicate.rumView(for: viewController)
    }

    /// The `UIViewController` indicating the active `RUMView`.
    private weak var lastStartedViewController: UIViewController?

    private func startIfNotStarted(rumView: RUMView, for viewController: UIViewController) {
        if viewController === lastStartedViewController {
            return
        }

        if subscriber == nil {
            userLogger.warn(
                """
                RUM View was started, but no `RUMMonitor` is registered on `GlobalDatadog.rum`. RUM auto instrumentation will not work.
                Make sure `GlobalDatadog.rum = RUMMonitor.initialize()` is called before any `UIViewController` is presented.
                """
            )
        }

        if let lastStartedViewController = lastStartedViewController {
            subscriber?.process(
                command: RUMStopViewCommand(
                    time: dateProvider.currentDate(),
                    attributes: rumView.attributes,
                    identity: lastStartedViewController
                )
            )
        }

        subscriber?.process(
            command: RUMStartViewCommand(
                time: dateProvider.currentDate(),
                identity: viewController,
                path: rumView.path,
                attributes: rumView.attributes
            )
        )

        lastStartedViewController = viewController
    }
}

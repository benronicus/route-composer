//
// Created by Eugene Kazaev on 15/01/2018.
// Copyright © 2018 HBC Digital. All rights reserved.
//

import UIKit

/// Default `Router` implementation
public struct DefaultRouter: InterceptableRouter, MainThreadChecking {

    // MARK: Properties

    /// `Logger` instance to be used by `DefaultRouter`.
    public let logger: Logger?

    /// `ContainerAdapter` instance.
    public let containerAdapterLocator: ContainerAdapterLocator

    private var interceptors: [AnyRoutingInterceptor] = []

    private var contextTasks: [AnyContextTask] = []

    private var postTasks: [AnyPostRoutingTask] = []

    // MARK: Methods

    /// Constructor
    ///
    /// Parameters
    ///   - logger: A `Logger` instance to be used by the `DefaultRouter`.
    ///   - containerAdapterLocator: A `ContainerAdapterLocator` instance to be used by the `DefaultRouter`.
    public init(logger: Logger? = nil,
                containerAdapterLocator: ContainerAdapterLocator = DefaultContainerAdapterLocator()) {
        self.logger = logger
        self.containerAdapterLocator = containerAdapterLocator
    }

    public mutating func add<RI: RoutingInterceptor>(_ interceptor: RI) where RI.Context == Any? {
        self.interceptors.append(RoutingInterceptorBox(interceptor))
    }

    public mutating func add<CT: ContextTask>(_ contextTask: CT) where CT.Context == Any? {
        self.contextTasks.append(ContextTaskBox(contextTask))
    }

    public mutating func add<PT: PostRoutingTask>(_ postTask: PT) where PT.Context == Any? {
        self.postTasks.append(PostRoutingTaskBox(postTask))
    }

    public func navigate<ViewController: UIViewController, Context>(to step: DestinationStep<ViewController, Context>,
                                                                    with context: Context,
                                                                    animated: Bool = true,
                                                                    completion: ((_: RoutingResult) -> Void)? = nil) throws {
        assertIfNotMainThread(logger: logger)
        do {
            let taskStack = try prepareTaskStack(with: context)

            // Builds stack of factories and finds a view controller to start a navigation process from.
            // Returns (rootViewController, factories) tuple
            // where rootViewController is the origin of the chain of views to be built for a given destination.
            let navigationStack = try prepareFactoriesStack(to: step, with: context, taskStack: taskStack)

            let viewController = navigationStack.rootViewController, factoriesStack = navigationStack.factories

            // Checks if the view controllers that are currently presented from the origin view controller, can be dismissed.
            if let viewController = Array([[viewController.allParents.last ?? viewController], viewController.allPresentedViewControllers].joined()).nonDismissibleViewController {
                throw RoutingError.compositionFailed(.init("\(String(describing: viewController)) view controller cannot " +
                        "be dismissed."))
            }

            startNavigation(from: viewController,
                    building: factoriesStack,
                    performing: taskStack,
                    with: context,
                    animated: animated,
                    completion: { (result: RoutingResult) in
                        if case let .failure(error) = result {
                            self.logger?.log(.error("\(error)"))
                            self.logger?.log(.info("Unsuccessfully finished the navigation process."))
                        } else {
                            self.logger?.log(.info("Successfully finished the navigation process."))
                        }
                        completion?(result)
                    })
        } catch {
            self.logger?.log(.error("\(error)"))
            self.logger?.log(.info("Unsuccessfully finished the navigation process."))
            throw error
        }
    }

    private func prepareTaskStack<Context>(with context: Context) throws -> GlobalTaskRunner {
        let interceptorRunner = try InterceptorRunner(interceptors: self.interceptors, with: context)
        let contextTaskRunner = try ContextTaskRunner(contextTasks: self.contextTasks, with: context)
        let postponedTaskRunner = PostponedTaskRunner()
        let postTaskRunner = PostTaskRunner(postTasks: self.postTasks, postponedRunner: postponedTaskRunner)
        return GlobalTaskRunner(interceptorRunner: interceptorRunner, contextTaskRunner: contextTaskRunner, postTaskRunner: postTaskRunner)
    }

    private func prepareFactoriesStack<Context>(to finalStep: RoutingStep, with context: Context, taskStack: GlobalTaskRunner) throws -> (rootViewController: UIViewController,
                                                                                                                                          factories: [AnyFactory]) {
        logger?.log(.info("Started to search for the view controller to start the navigation process from."))

        let result = try sequence(first: finalStep, next: { ($0 as? ChainableStep)?.getPreviousStep(with: context) })
                .compactMap({ $0 as? PerformableStep })
                .reduce((rootViewController: UIViewController?, factories: [AnyFactory])(rootViewController: nil, factories: []), { (result, step) in
                    guard result.rootViewController == nil else {
                        return result
                    }

                    // Creates a class responsible to run the tasks for this particular step
                    let stepTaskRunner = try taskStack.taskRunner(for: step, with: context)

                    // Performs current step
                    switch try step.perform(with: context) {
                    case .success(let viewController):
                        logger?.log(.info("\(String(describing: step)) found " +
                                "\(String(describing: viewController)) to start the navigation process from."))
                        try stepTaskRunner.perform(on: viewController, with: context)
                        return (rootViewController: viewController, result.factories)
                    case .build(let originalFactory):
                        // If the view controller to start from is not found, but the current step has a `Factory` to build it,
                        // then add factory to the stack
                        logger?.log(.info("\(String(describing: step)) hasn't found a corresponding view " +
                                "controller in the stack, so it will be built using \(String(describing: originalFactory))."))

                        // Wrap the `Factory` with the decorator that will
                        // handle the view controller and post task chain after the view controller creation.
                        var factory = FactoryDecorator(factory: originalFactory, stepTaskRunner: stepTaskRunner)

                        // Prepares the `Factory` for integration
                        // If a `Factory` cannot prepare itself (e.g. does not have enough data in context)
                        // then the view controllers stack can not be built
                        try factory.prepare(with: context)

                        // Allows to the `Factory` to change the current factory stack if needed.
                        var factories = try factory.scrapeChildren(from: result.factories)

                        // Adds the `Factory` to the beginning of the stack as the router is reading the configuration backwards.
                        factories.insert(factory, at: 0)
                        return (rootViewController: result.rootViewController, factories: factories)
                    case .none:
                        logger?.log(.info("\(String(describing: step)) hasn't found a corresponding view " +
                                "controller in the stack, so router will continue to search."))
                        return result
                    }
                })

        //Throws an exception if the router hasn't found a view controller to start the stack from.
        guard let rootViewController = result.rootViewController else {
            throw RoutingError.initialController(.notFound, .init("Unable to start the navigation process as the view controller to start from was not found."))
        }

        return (rootViewController: rootViewController, factories: result.factories)
    }

    private func startNavigation<Context>(from viewController: UIViewController,
                                          building factoriesStack: [AnyFactory],
                                          performing taskStack: GlobalTaskRunner,
                                          with context: Context,
                                          animated: Bool,
                                          completion: @escaping (RoutingResult) -> Void) {
        // Executes interceptors associated to each view in the chain. All the interceptors must succeed to
        // continue navigation process. This operation is async.
        let initialControllerDescription = String(describing: viewController)
        taskStack.performInterceptors(with: context) { [weak viewController] result in
            self.assertIfNotMainThread(logger: self.logger)

            if case let .failure(error) = result {
                completion(.failure(error))
                return
            }

            guard let viewController = viewController else {
                completion(.failure(RoutingError.initialController(.deallocated, .init("A view controller \(initialControllerDescription) that has been chosen as a " +
                        "starting point of the navigation process was destroyed while the router was waiting for the interceptors to finish."))))
                return
            }

            // Closes all the presented view controllers above the found view controller to be able
            // to build a new stack if needed.
            // This operation is async.
            // It was already confirmed that they can be dismissed.
            self.dismissPresentedIfNeeded(from: viewController, animated: animated) { result in
                guard result.isSuccessful else {
                    return completion(result)
                }

                // Builds view controller's stack using factories.
                // This operation is async.
                self.buildViewControllerStack(starting: viewController,
                        with: context,
                        using: factoriesStack,
                        animated: animated) { result in
                    do {
                        if case let .failure(error) = result {
                            throw error
                        }
                        try taskStack.performPostTasks(with: context)
                        completion(result)
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // Loops through the list of factories and builds their view controllers in sequence.
    // Some actions can be asynchronous, like push, modal or presentations,
    // so it performs them asynchronously
    private func buildViewControllerStack<Context>(starting rootViewController: UIViewController,
                                                   with context: Context,
                                                   using factories: [AnyFactory],
                                                   animated: Bool,
                                                   completion: @escaping ((RoutingResult) -> Void)) {
        var factories = factories

        let postponedIntegrationHandler = DefaultPostponedIntegrationHandler(logger: logger,
                containerAdapterLocator: containerAdapterLocator)

        func buildViewController(from previousViewController: UIViewController) {
            self.makeVisibleIfNeeded(previousViewController, animated: animated, completion: { result in
                do {
                    guard result.isSuccessful else {
                        self.logger?.log(.info("\(String(describing: previousViewController)) has stopped the navigation process " +
                                "as it was not able to become visible in the parent container."))
                        completion(result)
                        return
                    }
                    guard !factories.isEmpty else {
                        postponedIntegrationHandler.purge(animated: animated, completion: completion)
                        return
                    }
                    let factory = factories.removeFirst()
                    let newViewController = try factory.build(with: context)
                    self.logger?.log(.info("\(String(describing: factory)) built a \(String(describing: newViewController))."))

                    let nextAction = factories.first?.action

                    factory.action.perform(with: newViewController,
                            on: previousViewController,
                            with: postponedIntegrationHandler,
                            nextAction: nextAction,
                            animated: animated) { result in
                        self.assertIfNotMainThread(logger: self.logger)
                        guard result.isSuccessful else {
                            self.logger?.log(.info("\(String(describing: factory.action)) has stopped the navigation process " +
                                    "as it was not able to build a view controller into a stack."))
                            completion(result)
                            return
                        }
                        self.logger?.log(.info("\(String(describing: factory.action)) has applied to " +
                                "\(String(describing: previousViewController)) with \(String(describing: newViewController))."))
                        buildViewController(from: newViewController)
                    }
                } catch {
                    completion(.failure(error))
                }
            })
        }

        logger?.log(.info(factories.isEmpty ? "No view controllers needed to be integrated into the stack." : "Started to build the view controllers stack."))
        buildViewController(from: rootViewController)
    }

    private func makeVisibleIfNeeded(_ viewController: UIViewController,
                                     animated: Bool,
                                     completion: @escaping (RoutingResult) -> Void) {
        // If the previous view controller is created/found but it's view is not loaded or it has no window,
        // then it is cached by the container view controller like it would be in a `UITabBarController`s
        // tab that was never activated. So the router will have to activate it first.
        // Example: `UITabBarController` contains a navigation controller in the tab that was never opened and the router is going
        // to push a view controller into. UINavigationController in this case will not be able to update its content properly.
        if !viewController.isViewLoaded || viewController.view.window == nil {
            makeVisibleInParentContainer(viewController, animated: animated, completion: completion)
        } else {
            completion(.success)
        }
    }

    // Activates the origin view controller of viewController
    private func makeVisibleInParentContainer(_ viewController: UIViewController,
                                              animated: Bool,
                                              completion: @escaping (RoutingResult) -> Void) {
        var parentViewControllers = viewController.allParents

        func makeVisible(viewController: UIViewController, completion: @escaping (RoutingResult) -> Void) {
            guard !parentViewControllers.isEmpty else {
                completion(.success)
                return
            }
            do {
                let parentViewController = parentViewControllers.removeFirst()
                if let container = parentViewController as? ContainerViewController {
                    let containerAdapter = try containerAdapterLocator.getAdapter(for: container)
                    if containerAdapter.containedViewControllers.contains(viewController) {
                        containerAdapter.makeVisible(viewController, animated: animated, completion: { result in
                            guard result.isSuccessful else {
                                completion(result)
                                return
                            }
                            self.logger?.log(.info("Made \(String(describing: viewController)) visible in \(String(describing: container))"))
                            makeVisible(viewController: parentViewController, completion: completion)
                        })
                        return
                    }
                }
                makeVisible(viewController: parentViewController, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }

        makeVisible(viewController: viewController, completion: completion)
    }

    // Dismisses all the view controllers presented if there are any
    private func dismissPresentedIfNeeded(from viewController: UIViewController, animated: Bool, completion: @escaping ((_: RoutingResult) -> Void)) {
        if let presentedController = viewController.presentedViewController {
            if !presentedController.isBeingDismissed {
                viewController.dismiss(animated: animated) {
                    self.logger?.log(.info("Dismissed all the view controllers presented from \(String(describing: viewController))"))
                    completion(.success)
                }
            } else {
                completion(.failure(RoutingError.compositionFailed(.init("Attempt to dismiss \(String(describing: presentedController)) while it is being dismissed"))))
            }
        } else {
            completion(.success)
        }
    }

}

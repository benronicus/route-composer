//
// Created by Eugene Kazaev on 04/09/2018.
//

import Foundation
import UIKit

extension DefaultRouter {

    // It seems that it could've simplify stuff and potentially remove `DefaultDelayedIntegrationHandler`,
    // but it does not consider the fact that there might be a finder factory in the middle of the chain
    // in which might be few simultaneous pushes. So it seems like a is wrong direction to go.
    // Simple example:
    // Replace path to `try? router.navigate(to: ConfigurationHolder.configuration.emptyAndProductScreen, with: ProductContext(productId: "231"))`
    // in PromptViewController and you'll see why it if impossible with this approach
    struct StartingFactoryBox<C>: AnyFactory {

        var action: AnyAction

        private weak var startingViewController: UIViewController?

        private let initialControllerDescription: String

        private var context: C?

        init(startingViewController: UIViewController) {
            self.startingViewController = startingViewController
            self.initialControllerDescription = String(describing: startingViewController)
            self.action = ActionBox(ViewControllerActions.NilAction())
        }

        mutating func prepare<Context>(with context: Context) throws {
            guard let typedContext = Any?.some(context as Any) as? C else {
                throw RoutingError.typeMismatch(C.self, .init("\(String(describing: initialControllerDescription)) does " +
                        "not accept \(String(describing: context.self)) as a context."))
            }
            self.context = typedContext
        }

        func build<Context>(with context: Context) throws -> UIViewController {
            guard let startingViewController = self.startingViewController else {
                throw RoutingError.initialController(.deallocated, .init("A view controller \(initialControllerDescription) that has been chosen as a " +
                        "starting point of the navigation process was destroyed while the router was waiting for the interceptors to finish."))
            }
            return startingViewController
        }

        mutating func scrapeChildren(from factories: [AnyFactory]) throws -> [AnyFactory] {
            guard let startingViewController = startingViewController,
                  let container = factories.first?.action.findContainer(in: startingViewController) else {
                return factories
            }

            var otherFactories: [AnyFactory] = []
            var isNonEmbeddableFound = false
            let children = factories.compactMap({ child -> DelayedIntegrationFactory<C>? in
                guard !isNonEmbeddableFound, child.action.isEmbeddable(to: type(of: container)) else {
                    otherFactories.append(child)
                    isNonEmbeddableFound = true
                    return nil
                }
                return DelayedIntegrationFactory(child)
            })
            guard children.count > 1 else {
                return factories
            }
            guard let typedContext = Any?.some(context as Any) as? C else {
                throw RoutingError.typeMismatch(C.self, .init("\(String(describing: initialControllerDescription)) does " +
                        "not accept \(String(describing: context.self)) as a context."))
            }
            self.action = SimultaneousIntegrationAction(containerViewController: container, children: children, context: typedContext)
            return otherFactories
        }

        struct SimultaneousIntegrationAction<C>: AnyAction {

            private weak var containerViewController: ContainerViewController?

            private var children: [DelayedIntegrationFactory<C>] = []

            let context: C

            init(containerViewController: ContainerViewController, children: [DelayedIntegrationFactory<C>], context: C) {
                self.containerViewController = containerViewController
                self.children = children
                self.context = context
            }

            func findContainer(in viewController: UIViewController) -> ContainerViewController? {
                return nil
            }

            func perform(with viewController: UIViewController, on existingController: UIViewController, with delayedIntegrationHandler: DelayedActionIntegrationHandler, nextAction: AnyAction?, animated: Bool, completion: @escaping (ActionResult) -> Void) {
                guard let containerViewController = containerViewController else {
                    completion(.failure(RoutingError.compositionFailed(.init(""))))
                    return
                }
                do {
                    let containedViewControllers = try ChildCoordinator(childFactories: children).build(with: context, integrating: containerViewController.containedViewControllers)
                    containerViewController.replace(containedViewControllers: containedViewControllers, animated: animated, completion: {
                        completion(.continueRouting)
                    })
                } catch let error {
                    completion(.failure(error))
                }

            }

            func perform(embedding viewController: UIViewController, in childViewControllers: inout [UIViewController]) throws {
                return
            }

            func isEmbeddable(to container: ContainerViewController.Type) -> Bool {
                return false
            }
        }
    }

    struct InterceptorRunner {

        private var interceptors: [AnyRoutingInterceptor]

        init<Context>(interceptors: [AnyRoutingInterceptor], with context: Context) throws {
            self.interceptors = try interceptors.map({
                var interceptor = $0
                try interceptor.prepare(with: context)
                return interceptor
            })
        }

        mutating func add<Context>(_ interceptor: AnyRoutingInterceptor, with context: Context) throws {
            var interceptor = interceptor
            try interceptor.prepare(with: context)
            interceptors.append(interceptor)
        }

        func run<Context>(with context: Context, completion: @escaping (_: InterceptorResult) -> Void) {
            guard !interceptors.isEmpty else {
                completion(.continueRouting)
                return
            }
            let interceptorToRun = interceptors.count == 1 ? interceptors[0] : InterceptorMultiplexer(interceptors)
            interceptorToRun.execute(with: context, completion: completion)
        }

    }

    struct ContextTaskRunner {

        var contextTasks: [AnyContextTask]

        init<Context>(contextTasks: [AnyContextTask], with context: Context) throws {
            self.contextTasks = try contextTasks.map({
                var contextTask = $0
                try contextTask.prepare(with: context)
                return contextTask
            })
        }

        mutating func add<Context>(_ contextTask: AnyContextTask, with context: Context) throws {
            var contextTask = contextTask
            try contextTask.prepare(with: context)
            contextTasks.append(contextTask)
        }

        func run<Context>(on viewController: UIViewController, with context: Context) throws {
            try contextTasks.forEach({
                try $0.apply(on: viewController, with: context)
            })
        }

    }

    struct PostTaskRunner {

        var postTasks: [AnyPostRoutingTask]

        let delayedRunner: PostTaskDelayedRunner

        init<Context>(postTasks: [AnyPostRoutingTask], with context: Context, delayedRunner: PostTaskDelayedRunner) {
            self.postTasks = postTasks
            self.delayedRunner = delayedRunner
        }

        mutating func add<Context>(_ postTask: AnyPostRoutingTask, with context: Context) throws {
            postTasks.append(postTask)
        }

        func run<Context>(on viewController: UIViewController, with context: Context) throws {
            delayedRunner.add(postTasks: postTasks, to: viewController)
        }

        func commit<Context>(with context: Context) throws {
            try delayedRunner.run(with: context)
        }

    }

    struct StepTaskTaskRunner {

        private let contextTaskRunner: ContextTaskRunner

        private let postTaskRunner: PostTaskRunner

        init(contextTaskRunner: ContextTaskRunner, postTaskRunner: PostTaskRunner) {
            self.contextTaskRunner = contextTaskRunner
            self.postTaskRunner = postTaskRunner
        }

        func run<Context>(on viewController: UIViewController, with context: Context) throws {
            try contextTaskRunner.run(on: viewController, with: context)
            try postTaskRunner.run(on: viewController, with: context)
        }

    }

    final class PostTaskDelayedRunner {

        private struct PostTaskSlip {
            // This reference is weak because even though this view controller was created by a fabric but then some other
            // view controller in the chain can have an action that will actually remove this view controller from the
            // stack. We do not want to keep a strong reference to it and prevent it from deallocation. Potentially it's
            // a very rare issue but must be kept in mind.
            weak var viewController: UIViewController?

            let postTask: AnyPostRoutingTask
        }

        // this class is just a placeholder. Router needs at least one post routing task per view controller to
        // store a reference there.
        private struct EmptyPostTask: AnyPostRoutingTask {

            func execute<Context>(on viewController: UIViewController, with context: Context, routingStack: [UIViewController]) {
            }

        }

        private var taskSlips: [PostTaskSlip] = []

        func add(postTasks: [AnyPostRoutingTask], to viewController: UIViewController) {
            guard !postTasks.isEmpty else {
                let postTaskSlip = PostTaskSlip(viewController: viewController, postTask: EmptyPostTask())
                taskSlips.append(postTaskSlip)
                return
            }

            postTasks.forEach({
                let postTaskSlip = PostTaskSlip(viewController: viewController, postTask: $0)
                taskSlips.append(postTaskSlip)
            })
        }

        func run(with context: Any?) throws {
            var viewControllers: [UIViewController] = []
            taskSlips.forEach({
                guard let viewController = $0.viewController, !viewControllers.contains(viewController) else {
                    return
                }
                viewControllers.append(viewController)
            })

            try taskSlips.forEach({ slip in
                guard let viewController = slip.viewController else {
                    return
                }
                try slip.postTask.execute(on: viewController, with: context, routingStack: viewControllers)
            })
        }
    }

    class GlobalTaskRunner {

        private var interceptorRunner: InterceptorRunner

        private let contextTaskRunner: ContextTaskRunner

        private let postTaskRunner: PostTaskRunner

        init(interceptorRunner: InterceptorRunner, contextTaskRunner: ContextTaskRunner, postTaskRunner: PostTaskRunner) {
            self.interceptorRunner = interceptorRunner
            self.contextTaskRunner = contextTaskRunner
            self.postTaskRunner = postTaskRunner
        }

        func taskRunnerFor<Context>(step: PerformableStep?, with context: Context) throws -> StepTaskTaskRunner {
            guard let interceptableStep = step as? InterceptableStep else {
                return StepTaskTaskRunner(contextTaskRunner: self.contextTaskRunner, postTaskRunner: self.postTaskRunner)
            }
            var contextTaskRunner = self.contextTaskRunner
            var postTaskRunner = self.postTaskRunner
            if let interceptor = interceptableStep.interceptor {
                try interceptorRunner.add(interceptor, with: context)
            }
            if let contextTask = interceptableStep.contextTask {
                try contextTaskRunner.add(contextTask, with: context)
            }
            if let postTask = interceptableStep.postTask {
                try postTaskRunner.add(postTask, with: context)
            }
            return StepTaskTaskRunner(contextTaskRunner: contextTaskRunner, postTaskRunner: postTaskRunner)
        }

        func executeInterceptors<Context>(with context: Context, completion: @escaping (_: InterceptorResult) -> Void) {
            interceptorRunner.run(with: context, completion: completion)
        }

        func runPostTasks<Context>(with context: Context) throws {
            try postTaskRunner.commit(with: context)
        }

    }

    /// Each post action needs to know a view controller is should be applied to.
    /// This decorator adds functionality of storing `UIViewController`s created by the `Factory` and frees
    /// custom factories implementations from dealing with it. Mostly it is important for ContainerFactories
    /// which create merged view controllers without `Router`'s help.
    struct FactoryDecorator: AnyFactory, CustomStringConvertible {

        private var factory: AnyFactory

        private let stepTaskRunner: StepTaskTaskRunner

        var action: AnyAction {
            return factory.action
        }

        init(factory: AnyFactory, viewControllerTaskRunner: StepTaskTaskRunner) {
            self.factory = factory
            self.stepTaskRunner = viewControllerTaskRunner
        }

        mutating func prepare<Context>(with context: Context) throws {
            return try factory.prepare(with: context)
        }

        func build<Context>(with context: Context) throws -> UIViewController {
            let viewController = try factory.build(with: context)
            try stepTaskRunner.run(on: viewController, with: context)
            return viewController
        }

        mutating func scrapeChildren(from factories: [AnyFactory]) throws -> [AnyFactory] {
            return try factory.scrapeChildren(from: factories)
        }

        var description: String {
            return String(describing: factory)
        }

    }

    final class DefaultDelayedIntegrationHandler: DelayedActionIntegrationHandler {

        var containerViewController: ContainerViewController?

        var delayedViewControllers: [UIViewController] = []

        let logger: Logger?

        init(logger: Logger?) {
            self.logger = logger
        }

        func update(containerViewController: ContainerViewController, animated: Bool, completion: @escaping () -> Void) {
            guard self.containerViewController == nil else {
                purge(animated: animated, completion: {
                    self.update(containerViewController: containerViewController, animated: animated, completion: completion)
                })
                return
            }
            self.containerViewController = containerViewController
            self.delayedViewControllers = containerViewController.containedViewControllers
            logger?.log(.info("Container \(String(describing: containerViewController)) will be used for the delayed integration."))
            completion()
        }

        func update(delayedViewControllers: [UIViewController]) {
            self.delayedViewControllers = delayedViewControllers
        }

        func purge(animated: Bool, completion: @escaping () -> Void) {
            guard let containerViewController = containerViewController else {
                completion()
                return
            }

            guard !delayedViewControllers.isEqual(to: containerViewController.containedViewControllers) else {
                self.containerViewController = nil
                self.delayedViewControllers = []
                completion()
                return
            }

            containerViewController.replace(containedViewControllers: delayedViewControllers, animated: animated, completion: {
                self.logger?.log(.info("View controllers \(String(describing: self.delayedViewControllers)) were integrated together into \(containerViewController)"))
                self.containerViewController = nil
                self.delayedViewControllers = []
                completion()
            })
        }

    }

}

//
// Created by Eugene Kazaev on 2019-02-27.
//

import Foundation

struct ContainerActionBox<A: ContainerAction>: AnyAction, AnyActionBox, CustomStringConvertible, MainThreadChecking {

    let action: A

    init(_ action: A) {
        self.action = action
    }

    func perform(with viewController: UIViewController,
                 on existingController: UIViewController,
                 with delayedIntegrationHandler: DelayedActionIntegrationHandler,
                 nextAction: AnyAction?,
                 animated: Bool,
                 completion: @escaping (ActionResult) -> Void) {
        guard let containerController: A.ViewController = UIViewController.findContainer(of: existingController) else {
            completion(.failure(RoutingError.typeMismatch(ActionType.ViewController.self, RoutingError.Context("Container of " +
                    "\(String(describing: ActionType.ViewController.self)) type cannot be found to perform \(action)"))))
            return
        }
        assertIfNotMainThread()
        action.perform(with: viewController, on: containerController, animated: animated) { result in
            self.assertIfNotMainThread()
            completion(result)
        }
    }

    private func embed(viewController: UIViewController, with delayedIntegrationHandler: DelayedActionIntegrationHandler, completion: @escaping (ActionResult) -> Void) {
        do {
            var delayedChildControllers = delayedIntegrationHandler.delayedViewControllers
            try perform(embedding: viewController, in: &delayedChildControllers)
            delayedIntegrationHandler.update(delayedViewControllers: delayedChildControllers)
            completion(.continueRouting)
        } catch let error {
            completion(.failure(error))
        }
    }

    func perform(embedding viewController: UIViewController, in childViewControllers: inout [UIViewController]) throws {
        try action.perform(embedding: viewController, in: &childViewControllers)
    }

    public var description: String {
        return String(describing: action)
    }

    func isEmbeddable(to container: ContainerViewController.Type) -> Bool {
        return container is A.ViewController.Type
    }

    func findContainer(in viewController: UIViewController) -> ContainerViewController? {
        guard let containerController: A.ViewController = UIViewController.findContainer(of: viewController) else {
            return nil
        }
        return containerController
    }

}

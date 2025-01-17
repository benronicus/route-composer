//
// Created by Eugene Kazaev on 2018-09-17.
//

import Foundation
import UIKit

/// Represents a single step for the `Router` to make.
public struct DestinationStep<VC: UIViewController, C>: RoutingStep, ChainableStep {

    // MARK: Associated types

    /// Type of the `ViewController` associated with the step
    public typealias ViewController = VC

    /// Type of the `Context` associated with the step
    public typealias Context = C

    // MARK: Properties

    let destinationStep: RoutingStep

    // MARK: Methods

    init(_ destinationStep: RoutingStep) {
        self.destinationStep = destinationStep
    }

    func getPreviousStep<Context>(with context: Context) -> RoutingStep? {
        return destinationStep
    }

    /// Adapts context and view controller type dependencies.
    ///
    /// *NB:* Developer guaranties that this types will compliment in runtime.
    public func unsafelyRewrapped<VC: UIViewController, C>() -> DestinationStep<VC, C> {
        return DestinationStep<VC, C>(destinationStep)
    }

    /// Allows to avoid container view controller check.
    ///
    /// *NB:* Developer guaranties that it will be there in the runtime.
    public func expectingContainer<VC: ContainerViewController>() -> DestinationStep<VC, Context> {
        return DestinationStep<VC, Context>(destinationStep)
    }

}

// MARK: Helper Methods

/// A step that has a context type Optional(Any) can be build with any type of context passed to the router.
extension DestinationStep where DestinationStep.Context == Any? {

    /// Allows to avoid container view controller check. This method is available only for the steps that are
    /// able to accept any type of context.
    ///
    /// *NB:* Developer guaranties that it will be there in the runtime.
    public func expectingContainer<VC: ContainerViewController, C>() -> DestinationStep<VC, C> {
        return DestinationStep<VC, C>(destinationStep)
    }

    /// Allows to compliment to the type check. A step that has context equal to Optional(Any) can be build
    /// with any type of context passed to the router.
    public func adaptingContext<C>() -> DestinationStep<ViewController, C> {
        return DestinationStep<ViewController, C>(destinationStep)
    }

}

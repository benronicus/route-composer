//
// Created by Eugene Kazaev on 2018-11-07.
//

import Foundation
import UIKit

/// Default implementation of `StackIterator` protocol
public struct DefaultStackIterator: StackIterator {

    /// A starting point in the `UIViewController`s stack
    ///
    /// - topMost: Start from the topmost `UIViewController`
    /// - root: Start from the `UIWindow`s root `UIViewController`
    /// - custom: Start from the custom `UIViewController`
    public enum StartingPoint: Equatable {

        /// Start from the topmost `UIViewController`
        case topmost

        /// Start from the `UIWindow`s root `UIViewController`
        case root

        /// Start from the custom `UIViewController`
        case custom(@autoclosure () throws -> UIViewController?)

        public static func == (lhs: StartingPoint, rhs: StartingPoint) -> Bool {
            switch (lhs, rhs) {
            case (.root, .root):
                return true
            case (.topmost, .topmost):
                return true
            case let (.custom(lvc), .custom(rvc)):
                do {
                    return try lvc() === rvc()
                } catch {
                    return false
                }
            default:
                return false
            }
        }

    }

    /// `SearchOptions` to be used by `StackIteratingFinder`
    public let options: SearchOptions

    /// A starting point in the `UIViewController`s stack
    public let startingPoint: StartingPoint

    /// `WindowProvider` to get proper `UIWindow`
    public let windowProvider: WindowProvider

    /// `ContainerAdapter` instance.
    public let containerAdapterLocator: ContainerAdapterLocator

    /// Constructor
    public init(options: SearchOptions = .fullStack,
                startingPoint: StartingPoint = .topmost,
                windowProvider: WindowProvider = KeyWindowProvider(),
                containerAdapterLocator: ContainerAdapterLocator = DefaultContainerAdapterLocator()) {
        self.startingPoint = startingPoint
        self.options = options
        self.windowProvider = windowProvider
        self.containerAdapterLocator = containerAdapterLocator
    }

    /// Returns `UIViewController` instance if found
    ///
    /// - Parameter predicate: A block that contains `UIViewController` matching condition
    public func firstViewController(where predicate: (UIViewController) -> Bool) throws -> UIViewController? {
        guard let rootViewController = try getStartingViewController(),
              let viewController = try UIViewController.findViewController(in: rootViewController,
                      options: options,
                      containerAdapterLocator: containerAdapterLocator,
                      using: predicate) else {
            return nil
        }

        return viewController
    }

    func getStartingViewController() throws -> UIViewController? {
        switch startingPoint {
        case .topmost:
            return windowProvider.window?.topmostViewController
        case .root:
            return windowProvider.window?.rootViewController
        case let .custom(viewControllerClosure):
            return try viewControllerClosure()
        }
    }

}

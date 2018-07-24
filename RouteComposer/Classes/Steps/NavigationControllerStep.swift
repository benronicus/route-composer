//
// Created by Eugene Kazaev on 15/01/2018.
// Copyright (c) 2018 HBC Tech. All rights reserved.
//

import UIKit

/// Default navigation container step
public class NavigationControllerStep: BasicStep, RoutingStep {

    /// Creates the default `UINavigationController` and applies an `Action` if it is provided.
    ///
    /// - Parameters:
    ///     - action: The `Action` to be applied to the created `UINavigationController`
    public init(action: Action) {
        super.init(finder: NilFinder(), container: NavigationControllerFactory(action: action))
    }

}

//
// Created by Eugene Kazaev on 15/01/2018.
// Copyright © 2018 HBC Digital. All rights reserved.
//

import Foundation
import RouteComposer

let transitionController = BlurredBackgroundTransitionController()

protocol ExampleScreenConfiguration {

    var homeScreen: DestinationStep<UITabBarController, Any?> { get }

    var circleScreen: DestinationStep<CircleViewController, Any?> { get }

    var squareScreen: DestinationStep<SquareViewController, Any?> { get }

    var colorScreen: DestinationStep<ColorViewController, String> { get }

    var starScreen: DestinationStep<StarViewController, Any?> { get }

    var routingSupportScreen: DestinationStep<RoutingRuleSupportViewController, String> { get }

    var figuresScreen: DestinationStep<FiguresViewController, Any?> { get }

    var secondModalScreen: DestinationStep<SecondModalLevelViewController, String> { get }

    var welcomeScreen: DestinationStep<PromptViewController, Any?> { get }

    var figuresAndProductScreen: DestinationStep<ProductViewController, ProductContext> { get }

}

extension ExampleScreenConfiguration {

    var homeScreen: DestinationStep<UITabBarController, Any?> {
        return StepAssembly(
                // As both factory and finder are generic, You have to provide with at least one instance
                // the type of the view controller and the context to be used. You do not need to do so if you are using at
                // least one custom factory of finder that have set typealias for ViewController and Context.
                finder: ClassFinder<UITabBarController, Any?>(options: .current, startingPoint: .root),
                factory: StoryboardFactory(storyboardName: "TabBar"))
                .using(GeneralAction.replaceRoot(animationOptions: .transitionFlipFromLeft))
                .from(GeneralStep.root())
                .assemble()
    }

    var circleScreen: DestinationStep<CircleViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<CircleViewController, Any?>(),
                factory: NilFactory())
                .adding(ExampleGenericContextTask<CircleViewController, Any?>())
                .from(homeScreen)
                .assemble()
    }

    var squareScreen: DestinationStep<SquareViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<SquareViewController, Any?>(),
                factory: NilFactory())
                .adding(ExampleGenericContextTask<SquareViewController, Any?>())
                .from(homeScreen)
                .assemble()
    }

    var colorScreen: DestinationStep<ColorViewController, String> {
        return StepAssembly(
                finder: ColorViewControllerFinder(),
                factory: ColorViewControllerFactory())
                .adding(DismissalMethodProvidingContextTask(dismissalBlock: { (context, animated, completion) in
                    // Demonstrates ability to provide a dismissal method in the configuration using `DismissalMethodProvidingContextTask`
                    UIViewController.router.commitNavigation(to: GeneralStep.custom(using: PresentingFinder()), with: context, animated: animated, completion: completion)
                }))
                .adding(ExampleGenericContextTask<ColorViewController, String>())
                .using(ExampleNavigationController.push())
                .from(SingleContainerStep(finder: NilFinder(), factory: ExampleNavigationFactory<String>()))
                .using(GeneralAction.presentModally())
                .from(GeneralStep.current())
                .assemble()
    }

    var routingSupportScreen: DestinationStep<RoutingRuleSupportViewController, String> {
        return StepAssembly(
                finder: ClassFinder<RoutingRuleSupportViewController, String>(options: .currentAllStack),
                factory: StoryboardFactory(storyboardName: "TabBar", viewControllerID: "RoutingRuleSupportViewController"))
                .adding(ExampleGenericContextTask<RoutingRuleSupportViewController, String>())
                .using(UITabBarController.add())
                .from(TabBarControllerStep())
                .using(UINavigationController.push())
                .from(colorScreen.expectingContainer())
                .assemble()
    }

    var figuresScreen: DestinationStep<FiguresViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<FiguresViewController, Any?>(),
                factory: StoryboardFactory(storyboardName: "TabBar", viewControllerID: "FiguresViewController"))
                .adding(LoginInterceptor<Any?>())
                .adding(ExampleGenericContextTask<FiguresViewController, Any?>())
                .using(UINavigationController.push())
                .from(circleScreen.expectingContainer())
                .assemble()
    }

    var secondModalScreen: DestinationStep<SecondModalLevelViewController, String> {
        return StepAssembly(
                finder: ClassFinder<SecondModalLevelViewController, String>(),
                factory: StoryboardFactory(storyboardName: "TabBar", viewControllerID: "SecondModalLevelViewController"))
                .adding(ExampleGenericContextTask<SecondModalLevelViewController, String>())
                .using(UINavigationController.push())
                .from(NavigationControllerStep())
                .using(GeneralAction.presentModally(transitioningDelegate: transitionController))
                .from(routingSupportScreen)
                .assemble()
    }

    var welcomeScreen: DestinationStep<PromptViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<PromptViewController, Any?>(),
                factory: StoryboardFactory(storyboardName: "PromptScreen"))
                .adding(ExampleGenericContextTask<PromptViewController, Any?>())
                .using(GeneralAction.replaceRoot())
                .from(GeneralStep.root())
                .assemble()
    }

    var figuresAndProductScreen: DestinationStep<ProductViewController, ProductContext> {
        return StepAssembly(
                finder: ClassWithContextFinder<ProductViewController, ProductContext>(),
                factory: StoryboardFactory(storyboardName: "TabBar", viewControllerID: "ProductViewController"))
                .adding(ContextSettingTask())
                .using(UINavigationController.push())
                .assemble(from: figuresScreen.expectingContainer())
    }

}

struct ExampleConfiguration: ExampleScreenConfiguration {

    var starScreen: DestinationStep<StarViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<StarViewController, Any?>(options: .currentAllStack),
                factory: XibFactory())
                .adding(ExampleGenericContextTask<StarViewController, Any?>())
                .adding(LoginInterceptor<Any?>())
                .using(UITabBarController.add())
                .from(homeScreen)
                .assemble()
    }

}

struct AlternativeExampleConfiguration: ExampleScreenConfiguration {

    var starScreen: DestinationStep<StarViewController, Any?> {
        return StepAssembly(
                finder: ClassFinder<StarViewController, Any?>(options: .currentAllStack),
                factory: XibFactory())
                .adding(ExampleGenericContextTask<StarViewController, Any?>())
                .adding(LoginInterceptor())
                .using(UINavigationController.push())
                .from(circleScreen.expectingContainer())
                .assemble()
    }

}

class ConfigurationHolder {

    // Declared as static to avoid dependency injection in the Example app. So this variable is available everywhere.
    static var configuration: ExampleScreenConfiguration = ExampleConfiguration()

}

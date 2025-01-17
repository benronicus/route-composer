//
// Created by Eugene Kazaev on 11/09/2018.
// Copyright (c) 2018 HBC Digital. All rights reserved.
//

import Foundation
import UIKit
import XCTest
@testable import RouteComposer

class ExtensionsTest: XCTestCase {

    class InvisibleViewController: UIViewController {
    }

    class FakePresentingNavigationController: UINavigationController {

        var fakePresentingViewController: UIViewController?

        override var presentingViewController: UIViewController? {
            return fakePresentingViewController
        }

    }

    func testTopMostViewControllerSingle() {
        let window = UIWindow()
        let navigationController = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigationController
        XCTAssertEqual(window.topmostViewController, navigationController)
    }

    func testTopMostViewControllerMultiple() {
        let window = UIWindow()
        let viewController1 = RouterTests.TestModalPresentableController()
        let viewController2 = RouterTests.TestModalPresentableController()
        let navigationController = UINavigationController(rootViewController: UIViewController())
        viewController1.fakePresentedViewController = viewController2
        viewController2.fakePresentingViewController = viewController1
        viewController2.fakePresentedViewController = navigationController
        window.rootViewController = viewController1
        XCTAssertEqual(window.topmostViewController, navigationController)
    }

    func testAllPresentedViewController() {
        let viewController1 = RouterTests.TestModalPresentableController()
        let viewController2 = RouterTests.TestModalPresentableController()
        let navigationController = UINavigationController(rootViewController: UIViewController())
        viewController1.fakePresentedViewController = viewController2
        viewController2.fakePresentedViewController = navigationController
        XCTAssertEqual(viewController1.allPresentedViewControllers.count, 2)
        XCTAssertEqual(viewController2.allPresentedViewControllers.count, 1)
        XCTAssertEqual(navigationController.allPresentedViewControllers.count, 0)
    }

    func testFindViewControllerParent() {
        let tabBarController = UITabBarController()
        let navigationController = UINavigationController()
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()

        tabBarController.viewControllers = [navigationController]
        navigationController.viewControllers = [viewController1]
        viewController1.addChild(viewController2)
        viewController2.addChild(UISplitViewController())

        XCTAssertEqual(try? UIViewController.findViewController(in: viewController2, options: [.parent], using: { _ in return true }), viewController1)
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: [.current, .parent], using: { $0 is UISplitViewController }))
        XCTAssertEqual(try? UIViewController.findViewController(in: viewController2, options: [.current, .parent], using: { $0 is UINavigationController }), navigationController)
        XCTAssertEqual(try? UIViewController.findViewController(in: viewController2, options: [.current, .parent], using: { $0 is UITabBarController }), tabBarController)
    }

    func testFindViewController() {
        let viewController1 = RouterTests.TestModalPresentableController()
        let viewController2 = RouterTests.TestModalPresentableController()
        let testViewController = RouterTests.TestViewController()
        let invisibleController = InvisibleViewController()
        let viewController3 = FakePresentingNavigationController()
        viewController1.fakePresentedViewController = viewController2
        viewController2.fakePresentingViewController = viewController1
        viewController2.fakePresentedViewController = viewController3
        viewController3.fakePresentingViewController = viewController2
        viewController3.viewControllers = [invisibleController, testViewController]

        var searchOption = SearchOptions.current
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = .presented
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = .presenting
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))
    }

    func testFindViewControllerWithCombinedOptions() {
        let viewController1 = RouterTests.TestModalPresentableController()
        let viewController2 = RouterTests.TestModalPresentableController()
        let testViewController = RouterTests.TestViewController()
        let invisibleController = InvisibleViewController()
        let viewController3 = FakePresentingNavigationController()
        viewController1.fakePresentedViewController = viewController2
        viewController2.fakePresentingViewController = viewController1
        viewController2.fakePresentedViewController = viewController3
        viewController3.fakePresentingViewController = viewController2
        viewController3.viewControllers = [invisibleController, testViewController]

        var searchOption: SearchOptions = [.presented, .current]
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = [.presenting, .current]
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = [.visible, .presented]
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is InvisibleViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = [.contained, .presented]
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is InvisibleViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = .currentAllStack
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is InvisibleViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))

        searchOption = .currentVisibleOnly
        XCTAssertNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController1, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController2, options: searchOption, using: { $0 is RouterTests.TestModalPresentableController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: viewController3, options: searchOption, using: { $0 is InvisibleViewController }))
        XCTAssertNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is UINavigationController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: testViewController, options: searchOption, using: { $0 is RouterTests.TestViewController }))
        XCTAssertNotNil(try? UIViewController.findViewController(in: invisibleController, options: searchOption, using: { $0 is InvisibleViewController }))
    }

    func testTabBarControllerExtension() {
        let viewController1 = UIViewController()
        let viewController2 = UINavigationController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [viewController1, viewController2]
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: tabBarController).containedViewControllers.count, 2)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: tabBarController).visibleViewControllers.count, 1)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: tabBarController).visibleViewControllers[0], viewController1)
        try? DefaultContainerAdapterLocator().getAdapter(for: tabBarController).makeVisible(viewController2, animated: false, completion: { _ in })
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: tabBarController).visibleViewControllers[0], viewController2)
    }

    func testNavigationControllerExtension() {
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()
        let navigationController = UINavigationController()
        navigationController.viewControllers = [viewController1, viewController2]
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: navigationController).containedViewControllers.count, 2)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: navigationController).visibleViewControllers.count, 1)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: navigationController).visibleViewControllers[0], viewController2)
        try? DefaultContainerAdapterLocator().getAdapter(for: navigationController).makeVisible(viewController1, animated: false, completion: { _ in })
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: navigationController).visibleViewControllers[0], viewController1)
    }

    func testSplitControllerExtension() {
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()
        let splitController = UISplitViewController()
        splitController.preferredDisplayMode = .primaryHidden
        splitController.viewControllers = [viewController1, viewController2]
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: splitController).containedViewControllers.count, 2)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: splitController).visibleViewControllers.count, splitController.isCollapsed ? 1 : 2)
        XCTAssertEqual(try? DefaultContainerAdapterLocator().getAdapter(for: splitController).visibleViewControllers[0],
                splitController.isCollapsed ? viewController2 : viewController1)
    }

    func testArrayExtension() {
        let array1 = [UIViewController(), RouterTests.TestRoutingControllingViewController()]
        let array2 = [UIViewController(), UINavigationController(rootViewController: RouterTests.TestRoutingControllingViewController())]
        let array3 = [UIViewController(), UIViewController()]
        XCTAssertFalse(array1.canBeDismissed)
        XCTAssertFalse(array2.canBeDismissed)
        XCTAssertTrue(array3.canBeDismissed)

        XCTAssert(array1.nonDismissibleViewController is RouterTests.TestRoutingControllingViewController)
        XCTAssert(array2.nonDismissibleViewController is UINavigationController)
        XCTAssert(array3.nonDismissibleViewController == nil)
    }

    func testArrayExtensionUniqueElements() {
        let viewController1 = UIViewController()
        let viewController2 = RouterTests.TestRoutingControllingViewController()
        let array = [viewController1, viewController2, viewController1]
        XCTAssertEqual(array.uniqueElements().count, 2)
        XCTAssertEqual(array.uniqueElements()[0], viewController1)
        XCTAssertEqual(array.uniqueElements()[1], viewController2)
    }

    func testArrayExtensionIsEqual() {
        let viewController1 = UIViewController()
        let viewController2 = RouterTests.TestRoutingControllingViewController()
        let array = [viewController1, viewController2, viewController1]
        XCTAssertFalse(array.isEqual(to: []))
        XCTAssertFalse(array.isEqual(to: [viewController2, viewController1]))
        XCTAssertFalse(array.isEqual(to: [viewController2, UIViewController()]))
        XCTAssertFalse(array.isEqual(to: [viewController1, viewController1, viewController2]))
        XCTAssertTrue(array.isEqual(to: [viewController1, viewController2, viewController1]))
    }

    func testAllParents() {
        let viewController1 = UIViewController()
        let viewController2 = UIViewController()
        let viewController3 = UIViewController()
        viewController1.addChild(viewController2)
        viewController2.addChild(viewController3)

        XCTAssertEqual(viewController3.allParents.count, 2)
        XCTAssertEqual(viewController3.allParents[0], viewController2)
        XCTAssertEqual(viewController3.allParents[1], viewController1)
        XCTAssertEqual(viewController2.allParents.count, 1)
        XCTAssertEqual(viewController2.allParents[0], viewController1)
        XCTAssertEqual(viewController1.allParents.count, 0)
    }

    func testRoutingInterceptorHelpers() {

        class TestInterceptor<C>: RoutingInterceptor {

            typealias Context = C

            var prepareCallsCount = 0

            var performCallsCount = 0

            func prepare(with context: Context) throws {
                prepareCallsCount += 1
            }

            func perform(with context: Context, completion: @escaping (RoutingResult) -> Void) {
                performCallsCount += 1
                completion(.success)
            }
        }

        let interceptor1 = TestInterceptor<String>()
        var wasInCompletion = false
        XCTAssertNoThrow(try interceptor1.execute(with: "test", completion: { _ in
            wasInCompletion = true
        }))
        XCTAssertTrue(wasInCompletion)
        XCTAssertEqual(interceptor1.prepareCallsCount, 1)
        XCTAssertEqual(interceptor1.performCallsCount, 1)

        let interceptor2 = TestInterceptor<Any?>()
        wasInCompletion = false
        XCTAssertNoThrow(try interceptor2.execute(completion: { _ in
            wasInCompletion = true
        }))
        XCTAssertTrue(wasInCompletion)
        XCTAssertEqual(interceptor2.prepareCallsCount, 1)
        XCTAssertEqual(interceptor2.performCallsCount, 1)

        let interceptor3 = TestInterceptor<Any?>()
        wasInCompletion = false
        XCTAssertNoThrow(try interceptor3.execute(completion: { _ in
            wasInCompletion = true
        }))
        XCTAssertTrue(wasInCompletion)
        XCTAssertEqual(interceptor3.prepareCallsCount, 1)
        XCTAssertEqual(interceptor3.performCallsCount, 1)
    }

    func testContextTaskHelpers() {
        class TestContextTask<VC: UIViewController, C>: ContextTask {

            typealias ViewController = VC
            typealias Context = C

            var prepareCallsCount = 0

            var performCallsCount = 0

            func prepare(with context: Context) throws {
                prepareCallsCount += 1
            }

            func perform(on viewController: ViewController, with context: C) throws {
                performCallsCount += 1
            }
        }

        let contextTask1 = TestContextTask<UIViewController, String>()
        XCTAssertNoThrow(try contextTask1.execute(on: UIViewController(), with: "Test"))
        XCTAssertEqual(contextTask1.prepareCallsCount, 1)
        XCTAssertEqual(contextTask1.performCallsCount, 1)

        let contextTask2 = TestContextTask<UIViewController, Any?>()
        XCTAssertNoThrow(try contextTask2.execute(on: UIViewController()))
        XCTAssertEqual(contextTask2.prepareCallsCount, 1)
        XCTAssertEqual(contextTask2.performCallsCount, 1)

        let contextTask3 = TestContextTask<UIViewController, Void>()
        XCTAssertNoThrow(try contextTask3.execute(on: UIViewController()))
        XCTAssertEqual(contextTask3.prepareCallsCount, 1)
        XCTAssertEqual(contextTask3.performCallsCount, 1)
    }

}

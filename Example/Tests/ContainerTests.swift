import UIKit
import XCTest
@testable import RouteComposer

class ContainerTests: XCTestCase {

    func testChildViewControllersBuild() {
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.push()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.push()))!))
        try? prepare(children: &children)
        guard let childrenControllers = try? ChildCoordinator(childFactories: children).build(with: nil) else {
            XCTAssert(false, "Unable to build children view controllers")
            return
        }
        XCTAssertEqual(childrenControllers.count, 2)
    }

    func testNavigationControllerContainer() {
        let container = NavigationControllerFactory<Any?>()
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.push()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.push()))!))
        try? prepare(children: &children)
        guard let containerViewController = try? container.build(with: nil, integrating: ChildCoordinator(childFactories: children)) else {
            XCTAssert(false, "Unable to build UINavigationController")
            return
        }
        XCTAssertEqual(containerViewController.children.count, 2)
    }

    func testNavigationControllerContainer2() {
        var wasInConfiguration = false

        class Delegate: NSObject, UINavigationControllerDelegate {

        }

        let delegate = Delegate()
        let container = NavigationControllerFactory<Any?>(delegate: delegate, configuration: { controller in
            wasInConfiguration = true
            XCTAssertTrue(controller.delegate === delegate)
        })
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.push()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UINavigationController.pushReplacingLast()))!))
        try? prepare(children: &children)
        guard let containerViewController = try? container.build(with: nil, integrating: ChildCoordinator(childFactories: children)) else {
            XCTAssert(false, "Unable to build UINavigationController")
            return
        }
        XCTAssertEqual(containerViewController.children.count, 1)
        XCTAssertTrue(wasInConfiguration)
        XCTAssertThrowsError(try container.build(with: nil, integrating: ChildCoordinator(childFactories: [])))
    }

    func testTabBarControllerContainer() {
        var wasInConfiguration = false

        class Delegate: NSObject, UITabBarControllerDelegate {

        }

        let delegate = Delegate()
        let container = TabBarControllerFactory<Any?>(delegate: delegate, configuration: { controller in
            wasInConfiguration = true
            XCTAssertTrue(controller.delegate === delegate)
        })
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        try? prepare(children: &children)
        guard let containerViewController = try? container.build(with: nil, integrating: ChildCoordinator(childFactories: children)) else {
            XCTAssert(false, "Unable to build UITabBarController")
            return
        }
        XCTAssertEqual(containerViewController.children.count, 2)
        XCTAssertTrue(wasInConfiguration)
        XCTAssertThrowsError(try container.build(with: nil, integrating: ChildCoordinator(childFactories: [])))
    }

    func testSplitControllerContainer() {
        var wasInConfiguration = false

        class Delegate: UISplitViewControllerDelegate {

        }

        let delegate = Delegate()
        let container = SplitControllerFactory<Any?>(delegate: delegate,
                presentsWithGesture: true,
                preferredDisplayMode: .allVisible,
                configuration: { controller in
            wasInConfiguration = true
            XCTAssertEqual(controller.preferredDisplayMode, .allVisible)
            XCTAssertTrue(controller.delegate === delegate)
            XCTAssertTrue(controller.presentsWithGesture)
        })
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UISplitViewController.setAsMaster()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UISplitViewController.pushToDetails()))!))
        try? prepare(children: &children)
        guard let containerViewController = try? container.build(with: nil, integrating: ChildCoordinator(childFactories: children)) else {
            XCTAssert(false, "Unable to build UISplitViewController")
            return
        }
        XCTAssertEqual(containerViewController.children.count, 2)
        XCTAssertTrue(wasInConfiguration)
        XCTAssertThrowsError(try container.build(with: nil, integrating: ChildCoordinator(childFactories: [])))
    }

    func testCompleteFactory() {
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        try? prepare(children: &children)
        let factory = CompleteFactory(factory: TabBarControllerFactory(), childFactories: children)
        let viewController = try? factory.build(with: nil)
        XCTAssertNotNil(viewController)
        XCTAssertEqual(viewController?.viewControllers?.count, 2)
    }

    func testCompleteFactoryPrepareMethod() {

        class EmptyFactory: Factory {

            var prepareCount = 0

            init() {
            }

            func prepare(with context: Any?) throws {
                prepareCount += 1
            }

            func build(with context: Any?) throws -> UIViewController {
                return UIViewController()
            }

        }

        let childFactory1 = EmptyFactory()
        let childFactory2 = EmptyFactory()
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(childFactory1, action: ContainerActionBox(UITabBarController.add()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(childFactory2, action: ContainerActionBox(UITabBarController.add()))!))
        var factory = CompleteFactory(factory: TabBarControllerFactory(), childFactories: children)
        try? factory.prepare(with: nil)
        let viewController = try? factory.build(with: nil)
        XCTAssertNotNil(viewController)
        XCTAssertEqual(viewController?.viewControllers?.count, 2)
        XCTAssertEqual(childFactory1.prepareCount, 1)
        XCTAssertEqual(childFactory2.prepareCount, 1)
    }

    func testExecuteFactory() {
        var prepareCount = 0
        var buildCount = 0

        class TestFactory<C>: ContainerFactory {
            typealias ViewController = UINavigationController

            typealias Context = C

            var prepareBlock: () -> Void

            var buildBlock: () -> Void

            init(prepareBlock: @escaping () -> Void, buildBlock: @escaping () -> Void) {
                self.buildBlock = buildBlock
                self.prepareBlock = prepareBlock
            }

            func prepare(with context: C) throws {
                prepareBlock()
            }

            func build(with context: C, integrating coordinator: ChildCoordinator<C>) throws -> UINavigationController {
                buildBlock()
                return UINavigationController()
            }

        }

        let factory = TestFactory<Any?>(prepareBlock: { prepareCount += 1 }, buildBlock: { buildCount += 1 })
        XCTAssertNoThrow(try factory.execute(with: nil))
        XCTAssertEqual(prepareCount, 1)
        XCTAssertEqual(buildCount, 1)

        XCTAssertNoThrow(try factory.execute())
        XCTAssertEqual(prepareCount, 2)
        XCTAssertEqual(buildCount, 2)

        let voidFactory = TestFactory<Void>(prepareBlock: { prepareCount += 1 }, buildBlock: { buildCount += 1 })
        XCTAssertNoThrow(try voidFactory.execute())
        XCTAssertEqual(prepareCount, 3)
        XCTAssertEqual(buildCount, 3)
    }

    func testCompleteFactorySmartActions() {
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add(at: 0, replacing: true)))!))
        try? prepare(children: &children)
        let factory = CompleteFactory(factory: TabBarControllerFactory(), childFactories: children)
        let viewController = try? factory.build(with: nil)
        XCTAssertNotNil(viewController)
        XCTAssertEqual(viewController?.viewControllers?.count, 1)
    }

    func testCompleteFactoryDescription() {
        var children: [PostponedIntegrationFactory<Any?>] = []
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        children.append(PostponedIntegrationFactory<Any?>(for: FactoryBox(EmptyFactory(), action: ContainerActionBox(UITabBarController.add()))!))
        try? prepare(children: &children)
        let factory = CompleteFactory(factory: TabBarControllerFactory(), childFactories: children)
        XCTAssertEqual(factory.description, "TabBarControllerFactory<Optional<Any>>(delegate: nil, configuration: nil)")
    }

    private func prepare(children: inout [PostponedIntegrationFactory<Any?>]) throws {
        children = try children.map({
            var factory = $0
            try factory.prepare(with: nil)
            return factory
        })
    }

}

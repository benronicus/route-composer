//
// Created by Eugene Kazaev on 2018-11-07.
// Copyright (c) 2018 HBC Digital. All rights reserved.
//

import Foundation
import UIKit
import XCTest
@testable import RouteComposer

class FinderTest: XCTestCase {

    class TestContextCheckingViewController: UIViewController, ContextChecking {

        var context: String = "123"

        func isTarget(for context: String) -> Bool {
            return self.context == context
        }
    }

    func testInstanceFinder() {
        let viewController = UIViewController()
        let finder = InstanceFinder<UIViewController, Any?>(instance: viewController)
        XCTAssertEqual(finder.instance, viewController)
        XCTAssertEqual(try? finder.findViewController(with: nil), viewController)
        XCTAssertEqual(finder.getViewController(with: nil), viewController)
    }

    func testClassWithContextFinder() {
        let viewController = TestContextCheckingViewController()
        let finder = ClassWithContextFinder<TestContextCheckingViewController, String>(options: .currentAllStack, startingPoint: .custom(viewController))
        XCTAssertEqual(try? finder.findViewController(with: "123"), viewController)
    }

    func testNilFinder() {
        let finder = NilFinder<UIViewController, Any?>()
        XCTAssertNil(try? finder.findViewController(with: nil))
        XCTAssertNil(finder.getViewController(with: nil))
    }

    func testDefaultIteratorDefaultValues() {
        let iterator = DefaultStackIterator()
        XCTAssertEqual(iterator.options, .fullStack)
        XCTAssertEqual(iterator.startingPoint, .topmost)
        XCTAssertEqual(try? iterator.getStartingViewController(), UIApplication.shared.keyWindow?.topmostViewController)
    }

    func testDefaultIteratorNewValues() {
        let iterator = DefaultStackIterator(options: .current, startingPoint: .root)
        XCTAssertEqual(iterator.options, .current)
        XCTAssertEqual(iterator.startingPoint, .root)
        XCTAssertEqual(try? iterator.getStartingViewController(), UIApplication.shared.keyWindow?.rootViewController)
    }

    func testDefaultIteratorCustomStartingPoint() {

        struct TestInstanceFinder<VC: UIViewController, C>: Finder {
            private(set) weak var instance: VC?

            public init(instance: VC?) {
                self.instance = instance
            }

            public func findViewController(with context: C) -> VC? {
                return instance
            }

        }

        var currentViewController: UIViewController? = UIViewController()
        let iterator = DefaultStackIterator(options: .current,
                startingPoint: .custom(try TestInstanceFinder<UIViewController, Any?>(instance: currentViewController).findViewController()))
        XCTAssertEqual(iterator.options, .current)
        XCTAssertEqual(iterator.startingPoint, .custom(currentViewController))
        XCTAssertEqual(try? iterator.getStartingViewController(), currentViewController)

        currentViewController = nil
        XCTAssertEqual(iterator.startingPoint, .custom(nil))
        XCTAssertEqual(try? iterator.getStartingViewController(), nil)
    }

    func testStartingPointEquatable() {
        let currentViewController = UIViewController()
        let currentViewController1 = UIViewController()

        XCTAssertEqual(DefaultStackIterator.StartingPoint.topmost, DefaultStackIterator.StartingPoint.topmost)
        XCTAssertEqual(DefaultStackIterator.StartingPoint.root, DefaultStackIterator.StartingPoint.root)
        XCTAssertEqual(DefaultStackIterator.StartingPoint.custom(currentViewController), DefaultStackIterator.StartingPoint.custom(currentViewController))
        XCTAssertEqual(DefaultStackIterator.StartingPoint.custom(nil), DefaultStackIterator.StartingPoint.custom(nil))
        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.custom(currentViewController), DefaultStackIterator.StartingPoint.custom(currentViewController1))
        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.custom(currentViewController1), DefaultStackIterator.StartingPoint.custom(currentViewController))
        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.custom(currentViewController1), DefaultStackIterator.StartingPoint.custom(nil))

        func throwsException() throws -> UIViewController? {
            throw RoutingError.generic(.init("Test Error"))
        }

        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.custom(try throwsException()), DefaultStackIterator.StartingPoint.custom(currentViewController1))
        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.topmost, DefaultStackIterator.StartingPoint.root)
        XCTAssertNotEqual(DefaultStackIterator.StartingPoint.topmost, DefaultStackIterator.StartingPoint.custom(currentViewController))
    }

    func testSearchOptionsDescription() {
        let fullStack = SearchOptions.fullStack
        XCTAssertEqual(fullStack.description, "current, contained, presented, presenting")

        let currentVisibleOnly = SearchOptions.currentVisibleOnly
        XCTAssertEqual(currentVisibleOnly.description, "current, visible")

        let someOptions = [SearchOptions.current, .contained, .parent]
        XCTAssertEqual(someOptions.description, "[current, contained, parent]")
    }

}

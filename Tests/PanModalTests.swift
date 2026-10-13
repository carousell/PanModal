//
//  PanModalTests.swift
//  PanModalTests
//
//  Created by Tosin Afolabi on 2/26/19.
//  Copyright © 2019 PanModal. All rights reserved.
//

import XCTest
@testable import PanModal

/**
 ⚠️ Run tests on iPhone 8 iOS (12.1) Sim
 */

class PanModalTests: XCTestCase {

    class MockViewController: UIViewController, PanModalPresentable {
        var panScrollable: UIScrollView? { return nil }
    }

    class AdjustedMockViewController: UITableViewController, PanModalPresentable {
        var panScrollable: UIScrollView? { return tableView }
        var shortFormHeight: PanModalHeight { return .contentHeight(300) }
        var longFormHeight: PanModalHeight { return .maxHeightWithTopInset(50) }
        // for testing purposes - to mimic safe area insets
        var topLayoutOffset: CGFloat { return 20 }
        var bottomLayoutOffset: CGFloat { return 44 }
    }

    private var vc: AdjustedMockViewController!

    override func setUp() {
        super.setUp()
        vc = AdjustedMockViewController()
    }

    override func tearDown() {
        super.tearDown()
        vc = nil
    }

    func testPresentableDefaults() {

        let vc = MockViewController()

        XCTAssertEqual(vc.topOffset, 41.0)
        XCTAssertEqual(vc.shortFormHeight, PanModalHeight.maxHeight)
        XCTAssertEqual(vc.longFormHeight, PanModalHeight.maxHeight)
        XCTAssertEqual(vc.springDamping, 0.8)
        XCTAssertEqual(vc.panModalBackgroundColor, UIColor.black.withAlphaComponent(0.7))
        XCTAssertEqual(vc.dragIndicatorBackgroundColor, UIColor.lightGray)
        XCTAssertEqual(vc.scrollIndicatorInsets, .zero)
        XCTAssertEqual(vc.anchorModalToLongForm, true)
        XCTAssertEqual(vc.allowsExtendedPanScrolling, false)
        XCTAssertEqual(vc.allowsDragToDismiss, true)
        XCTAssertEqual(vc.allowsTapToDismiss, true)
        XCTAssertEqual(vc.isUserInteractionEnabled, true)
        XCTAssertEqual(vc.isHapticFeedbackEnabled, true)
        XCTAssertEqual(vc.shouldRoundTopCorners, false)
        XCTAssertEqual(vc.showDragIndicator, false)
        XCTAssertEqual(vc.shouldRoundTopCorners, false)
        XCTAssertEqual(vc.cornerRadius, 8.0)
        XCTAssertEqual(vc.transitionDuration, PanModalAnimator.Constants.defaultTransitionDuration)
        XCTAssertEqual(vc.transitionAnimationOptions, [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState])
    }

    func testPresentableYValues() {

        XCTAssertEqual(vc.topLayoutOffset, 20)
        XCTAssertEqual(vc.bottomLayoutOffset, 44)

        XCTAssertEqual(vc.topMargin(from: .maxHeight), 0)
        XCTAssertEqual(vc.topMargin(from: .maxHeightWithTopInset(40)), 40)
        XCTAssertEqual(vc.topMargin(from: .contentHeight(200)), 447)
        XCTAssertEqual(vc.topMargin(from: .contentHeightIgnoringSafeArea(200)), 447)

        XCTAssertEqual(vc.shortFormYPos, 388)
        XCTAssertEqual(vc.longFormYPos, 91)
        XCTAssertEqual(vc.bottomYPos, vc.view.frame.height)

        XCTAssertEqual(vc.view.frame.height, UIScreen.main.bounds.size.height - 20)
    }

    class HaltingMockViewController: UITableViewController, PanModalPresentable {
        var panScrollable: UIScrollView? { return tableView }
        var allowsExtendedPanScrolling: Bool { return false }
        // the demo app compiles PanModal's sources a second time, so the transitioningDelegate cast fails under test
        override var isPanModalPresented: Bool { return true }
    }

    /**
     Pins the scroll view to a content offset from inside the content offset change,
     the way UITableView's `_updateVisibleCellsNow:` re-adjusts it while self-sizing cells are measured.
     */
    class ContentOffsetPinner: NSObject {
        let depthLimit = 50
        private(set) var maxDepth = 0
        private var depth = 0
        private var observation: NSKeyValueObservation?

        init(scrollView: UIScrollView, pinnedYOffset: CGFloat) {
            super.init()
            observation = scrollView.observe(\.contentOffset) { [weak self] scrollView, _ in
                guard let self = self else { return }
                self.depth += 1
                self.maxDepth = max(self.maxDepth, self.depth)
                defer { self.depth -= 1 }
                guard self.depth < self.depthLimit, scrollView.contentOffset.y != pinnedYOffset else { return }
                scrollView.contentOffset = CGPoint(x: 0, y: pinnedYOffset)
            }
        }

        func stop() {
            observation?.invalidate()
        }
    }

    func testHaltScrollingIsNotReenteredWhenContentOffsetChangesDuringHalt() {
        let presentingVC = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13.0, *) {
            window.windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        }
        window.rootViewController = presentingVC
        window.makeKeyAndVisible()

        let presentedVC = HaltingMockViewController()
        let presented = expectation(description: "pan modal presented")
        presentingVC.presentPanModal(presentedVC) { presented.fulfill() }
        wait(for: [presented], timeout: 5)

        let pinner = ContentOffsetPinner(scrollView: presentedVC.tableView, pinnedYOffset: 10)
        presentedVC.tableView.contentOffset = CGPoint(x: 0, y: 10)
        pinner.stop()

        XCTAssertLessThan(pinner.maxDepth, 5, "haltScrolling kept re-entering through content offset KVO")

        presentingVC.dismiss(animated: false)
        window.isHidden = true
    }
}

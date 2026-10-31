//
//  UsernameGeneratorUITests.swift
//  UsernameGeneratorUITests
//
//  Runs on macOS, iPhone, iPad and Apple Vision. The app is launched with `-uiTesting`, which gives
//  it a clean settings store, so every test starts from the default options.
//

import XCTest
#if os(macOS)
import AppKit
#endif

final class UsernameGeneratorUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.activate()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No usernames appeared")
    }

    // MARK: - Helpers

    private var rows: XCUIElementQuery {
        app.buttons.matching(identifier: "username")
    }

    private var usernames: [String] {
        scrollToTop()
        return rows.allElementsBoundByIndex.map(\.label)
    }

    /// The form's scroll container. Gestures need a real element; on visionOS the app element has no scene to send them to.
    private var form: XCUIElement {
        let list = app.collectionViews.firstMatch
        return list.exists ? list : app.scrollViews.firstMatch
    }

    /// Changing an option can scroll the form down, and rows that leave the screen stop existing.
    private func scrollToTop() {
        for _ in 0..<10 where !(app.buttons["generate"].exists && app.buttons["generate"].isHittable) {
            #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: 300)
            #else
            form.swipeDown()
            #endif
        }
    }

    private func generate() {
        scrollToTop()
        press(app.buttons["generate"])
    }

    /// iPhone and iPad expose a stepper as two buttons named "<id>-Increment" and "<id>-Decrement".
    /// macOS and visionOS expose one stepper element instead, and visionOS names its buttons "plus" and "minus".
    private func stepperButton(_ id: String, up: Bool) -> XCUIElement {
        #if os(iOS)
        app.buttons["\(id)-\(up ? "Increment" : "Decrement")"]
        #else
        app.steppers[id].buttons[up ? "plus" : "minus"]
        #endif
    }

    private func stepperExists(_ id: String) -> Bool {
        #if os(iOS)
        app.buttons["\(id)-Increment"].exists
        #else
        app.steppers[id].exists
        #endif
    }

    /// Finds an element by identifier whatever its type, since SwiftUI maps controls differently per platform.
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Scrolls the form until the element can be hit. Rows off screen don't exist until they scroll into view,
    /// so start from the top to reach rows above the current position as well as below it.
    private func reveal(_ element: XCUIElement) {
        if !(element.exists && element.isHittable) { scrollToTop() }
        for _ in 0..<10 where !(element.exists && element.isHittable) {
            #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -300)
            #else
            form.swipeUp()
            #endif
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(element) can't be reached")
    }

    private func toggle(_ id: String) {
        let control = app.switches[id]
        reveal(control)
        #if os(macOS)
        control.click()
        #elseif os(visionOS)
        // The switch element covers the whole row, and tapping anywhere on it toggles.
        control.tap()
        #else
        // The row's label is also tappable text, so aim for the switch itself.
        // It sits a fixed distance from the trailing edge, however wide the row is.
        control.coordinate(withNormalizedOffset: CGVector(dx: 1 - 45 / control.frame.width, dy: 0.5)).tap()
        #endif
    }

    private func step(_ id: String, up: Bool, times: Int = 1) {
        let stepper = app.steppers[id]
        reveal(stepperButton(id, up: up))
        for _ in 0..<times {
            #if os(macOS)
            (up ? stepper.incrementArrows : stepper.decrementArrows).firstMatch.click()
            #else
            stepperButton(id, up: up).tap()
            #endif
        }
    }

    /// Clicks on macOS and taps elsewhere.
    private func press(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    /// The visible text of an element. Static text keeps it in `value` on some platforms.
    private func text(_ id: String) -> String {
        let element = element(id)
        return element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    /// The UI updates a moment after a tap, so wait for the condition instead of reading once.
    private func wait(_ message: String, timeout: TimeInterval = 5, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(condition(), message)
    }

    private func capitals(in name: String) -> Int {
        name.filter(\.isUppercase).count
    }

    // MARK: - Tests

    @MainActor
    func testLaunchShowsFiveUsernames() {
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(usernames.allSatisfy { !$0.isEmpty })
        XCTAssertTrue(element("strength").exists)
        XCTAssertTrue(element("generate").exists)
    }

    @MainActor
    func testGenerateReplacesUsernames() {
        let before = usernames
        generate()
        wait("Usernames did not change") { usernames != before }
        XCTAssertEqual(rows.count, 5)
    }

    @MainActor
    func testTappingAUsernameCopiesIt() {
        let name = rows.firstMatch.label
        press(rows.firstMatch)
        wait("Row was not marked as copied") { rows.firstMatch.value as? String == "Copied" }
        #if os(macOS)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), name)
        #endif
    }

    @MainActor
    func testWordCountChangesUsernames() {
        // Title case with no separator: each word starts with one capital letter.
        XCTAssertTrue(usernames.allSatisfy { capitals(in: $0) == 2 }, "\(usernames)")
        let strength = text("strength")
        XCTAssertFalse(strength.isEmpty)
        step("wordCount", up: true)
        wait("Usernames did not get a third word") { usernames.allSatisfy { capitals(in: $0) == 3 } }
        XCTAssertNotEqual(text("strength"), strength)
    }

    @MainActor
    func testTurningNumbersOff() {
        XCTAssertTrue(usernames.allSatisfy { $0.contains(where: \.isNumber) })
        // Rows below the fold only exist once scrolled to, so bring the toggle and its stepper into view first.
        reveal(app.switches["addNumbers"])
        XCTAssertTrue(stepperExists("digitCount"))
        toggle("addNumbers")
        wait("Usernames still have numbers") { usernames.allSatisfy { !$0.contains(where: \.isNumber) } }
        XCTAssertFalse(stepperExists("digitCount"))
    }

    @MainActor
    func testLengthLimitIsRespected() {
        toggle("limitLength")
        step("maxLength", up: false, times: 9)
        wait("Usernames are longer than 6") { usernames.allSatisfy { $0.count <= 6 } }
        generate()
        wait("New usernames are longer than 6") { usernames.allSatisfy { $0.count <= 6 } }
    }

    @MainActor
    func testOneWordDisablesPatternAndAlliteration() {
        reveal(element("pattern"))
        XCTAssertTrue(element("alliterate").isEnabled)
        step("wordCount", up: false)
        wait("Usernames did not drop to one word") { usernames.allSatisfy { capitals(in: $0) == 1 } }
        reveal(element("alliterate"))
        XCTAssertFalse(element("alliterate").isEnabled)
        XCTAssertFalse(element("pattern").exists)
        XCTAssertTrue(element("patternFixed").exists)
    }

    @MainActor
    func testLettersAndNumbersOnlyDisablesSeparators() {
        reveal(element("separatorMenu"))
        XCTAssertTrue(element("separatorMenu").isEnabled)
        toggle("lettersOnly")
        reveal(element("separatorMenu"))
        wait("Separator menu is still enabled") { !element("separatorMenu").isEnabled }
    }

    @MainActor
    func testPickingASecondSeparator() {
        reveal(element("separatorMenu"))
        #if os(iOS)
        // On iPhone and iPad the whole row is one button, but only the value at the trailing edge opens the menu.
        let menu = element("separatorMenu")
        menu.coordinate(withNormalizedOffset: CGVector(dx: 1 - 40 / menu.frame.width, dy: 0.5)).tap()
        #else
        press(element("separatorMenu"))
        #endif
        let hyphen = app.descendants(matching: .any)["Hyphen ( - )"].firstMatch
        XCTAssertTrue(hyphen.waitForExistence(timeout: 5))
        press(hyphen)
        #if !os(macOS)
        // The menu stays open on iOS and visionOS so several choices can be made. Tap outside to close it.
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.12)).tap()
        // The menu row may have scrolled out of view, and a missing element can't be read.
        reveal(element("separatorMenu"))
        wait("Separator menu does not show 2 separators") { element("separatorMenu").label.contains("2 separators") }
        #endif

        // Each username picks either no separator or a hyphen, so hyphens turn up across a few batches.
        var sawHyphen = false
        for _ in 0..<10 where !sawHyphen {
            let before = usernames
            generate()
            wait("Usernames did not change") { usernames != before }
            sawHyphen = usernames.contains { $0.contains("-") }
        }
        XCTAssertTrue(sawHyphen)
    }
}

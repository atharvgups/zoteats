import XCTest

/// Scripted demo tour of the app, driven in CI while the simulator screen is
/// recorded. This is a demo driver, not an assertion suite — it interacts
/// defensively (only taps what exists) so a slow feed never fails the video.
final class DemoTourUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testDemoTour() {
        let app = XCUIApplication()
        app.launch()

        // ── Dining ────────────────────────────────────────────────────────
        pause(4) // let live menus load

        // Switch halls: Brandywine, then back to The Anteatery.
        tapIfPresent(app.buttons["Brandywine, Middle Earth"])
        pause(2.5)
        tapIfPresent(app.buttons["The Anteatery, Mesa Court"])
        pause(2)

        // Browse meal periods (Breakfast / Lunch / Dinner only).
        tapFirstMatch(app.buttons, labels: ["Lunch", "Breakfast"])
        pause(2.5)
        tapFirstMatch(app.buttons, labels: ["Dinner"])
        pause(2.5)

        // Open the first dish's detail sheet — expand nutrition, add to plate.
        let firstDish = app.buttons.matching(identifier: "dish-row").firstMatch
        if firstDish.waitForExistence(timeout: 5) {
            firstDish.tap()
            pause(3)
            tapIfPresent(app.buttons.matching(identifier: "full-nutrition-toggle").firstMatch)
            pause(2)
            // Favorite from the sheet, then add to plate.
            tapFirstMatch(app.buttons, labelPrefixes: ["Add to Favorites", "Add "])
            pause(1)
            tapFirstMatch(app.buttons, labelPrefixes: ["Add to My Plate"])
            pause(1.5)
            tapIfPresent(app.buttons["Close"])
            pause(1.5)
        }

        // Floating plate tally → My Plate sheet.
        tapIfPresent(app.buttons.matching(identifier: "plate-tally-bar").firstMatch)
        pause(2.5)
        tapIfPresent(app.buttons["Close plate"])
        pause(1.5)

        // Also tap + on a row if the sheet path didn't seed the plate.
        tapIfPresent(app.buttons.matching(identifier: "plate-toggle").firstMatch)
        pause(1.5)

        // Browse tomorrow's menu, then come back to today.
        tapIfPresent(app.buttons["Menu for Tomorrow"])
        pause(3)
        tapIfPresent(app.buttons["Menu for Today"])
        pause(2)

        // Open Filters sheet — pick a diet, then clear.
        tapIfPresent(app.buttons["diet-filter-chip"])
        pause(2)
        tapFirstMatch(app.buttons, labelPrefixes: ["Vegan filter", "Vegetarian filter"])
        pause(1.5)
        tapIfPresent(app.buttons["diet-filter-done"])
        pause(2)
        tapIfPresent(app.buttons["diet-filter-chip"])
        pause(1.5)
        tapIfPresent(app.buttons["diet-filter-clear"])
        pause(1)
        tapIfPresent(app.buttons["diet-filter-done"])
        pause(1.5)

        // Scroll through the menu.
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        app.swipeDown()
        app.swipeDown()
        pause(1.5)

        // ── Campus: filters, brand groups, menu sheet ─────────────────────
        tapTab(app, "Campus")
        pause(3.5)
        // Filter by category, then clear it.
        tapIfPresent(app.buttons["Coffee"])
        pause(2.5)
        tapIfPresent(app.buttons["Coffee"])
        pause(1.5)
        // Toggle the open-now filter on, then back off (everything shows by default).
        tapFirstMatch(app.buttons, labelPrefixes: ["Showing all spots"])
        pause(2.5)
        tapFirstMatch(app.buttons, labelPrefixes: ["Showing open spots"])
        pause(1.5)
        // Expand and collapse a multi-location brand group (e.g. Starbucks).
        tapFirstMatch(app.buttons, labelPrefixes: ["Starbucks,", "Zot N Go"])
        pause(2.5)
        tapFirstMatch(app.buttons, labelPrefixes: ["Starbucks,", "Zot N Go"])
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        // Open Halal Shack (publishes a menu): scroll until the row is actually
        // hittable — the Food Courts section sits deep in the list.
        let halalShack = app.buttons["campus-place-halal-shack"]
        _ = halalShack.waitForExistence(timeout: 5)
        var scrollAttempts = 0
        while !halalShack.isHittable, scrollAttempts < 6 {
            app.swipeUp()
            pause(1)
            scrollAttempts += 1
        }
        if halalShack.isHittable {
            halalShack.tap()
            pause(3.5)
            tapIfPresent(app.buttons["Vegetarian"])
            pause(2.5)
            tapIfPresent(app.buttons["Vegetarian"])
            pause(1.5)
            tapIfPresent(app.buttons["Close"])
            pause(1.5)
        }
        app.swipeDown()
        app.swipeDown()
        pause(1)

        // ── Gym: busyness hero, rush chart, expandable hours ──────────────
        tapTab(app, "Gym")
        pause(3.5)
        tapFirstMatch(app.buttons, labelPrefixes: ["Show this week's hours"])
        pause(2.5)
        app.swipeUp()
        pause(2)

        // ── Study ─────────────────────────────────────────────────────────
        tapTab(app, "Study")
        pause(3.5)
        // Expand the first facility's sub-areas.
        tapFirstMatch(app.buttons, labelPrefixes: ["Show floors inside", "Show areas inside"])
        pause(2.5)
        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(1.5)

        // ── Settings (top-right gear): appearance + notifications ─────────
        tapTab(app, "Eat")
        pause(2)
        tapIfPresent(app.buttons["Open settings"].firstMatch)
        pause(2.5)
        tapIfPresent(app.buttons["Dark appearance"])
        pause(2)
        tapIfPresent(app.buttons["System appearance"])
        pause(1.5)
        // Scroll to notifications / widgets tips.
        app.swipeUp()
        pause(1.5)
        // Accept the system notification permission alert if it appears.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        tapIfPresent(app.buttons["favorite-alerts-toggle"])
        pause(1)
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        pause(1.5)
        tapIfPresent(app.buttons["test-notification-button"])
        pause(2)
        tapIfPresent(app.buttons["opening-alerts-row"])
        pause(2.5)
        tapIfPresent(app.buttons["Close opening alerts"])
        pause(1.5)
        tapIfPresent(app.buttons["Close settings"])
        pause(2.5)
    }

    // MARK: - Helpers

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval = 3) {
        if element.waitForExistence(timeout: timeout), element.isHittable {
            element.tap()
        }
    }

    /// Tab buttons moved out of the classic tab-bar hierarchy with the iOS 26
    /// glass bar + Tab API; try several queries, then a bottom-edge coordinate tap.
    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let candidates: [XCUIElement] = [
            app.tabBars.buttons[name],
            app.buttons[name],
            app.descendants(matching: .any)[name].firstMatch,
        ]
        for candidate in candidates {
            if candidate.waitForExistence(timeout: 2), candidate.isHittable {
                candidate.tap()
                return
            }
        }
        // Last resort: Liquid Glass sometimes reports tabs as non-hittable.
        let index: CGFloat
        switch name {
        case "Eat": index = 0
        case "Campus": index = 1
        case "Gym": index = 2
        case "Study": index = 3
        default: return
        }
        let x = (index + 0.5) / 4.0
        let coord = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.96))
        coord.tap()
    }

    private func tapFirstMatch(_ query: XCUIElementQuery, labels: [String]) {
        for label in labels {
            let element = query[label]
            if element.exists, element.isHittable {
                element.tap()
                return
            }
        }
    }

    private func tapFirstMatch(_ query: XCUIElementQuery, labelPrefixes: [String]) {
        for prefix in labelPrefixes {
            let element = query.matching(
                NSPredicate(format: "label BEGINSWITH %@", prefix)
            ).firstMatch
            if element.waitForExistence(timeout: 2), element.isHittable {
                element.tap()
                return
            }
        }
    }
}

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

        // Browse meal periods.
        tapFirstMatch(app.buttons, labels: ["Lunch", "Brunch", "Breakfast"])
        pause(2.5)
        tapFirstMatch(app.buttons, labels: ["Dinner", "All Day"])
        pause(2.5)

        // Open the first dish's detail sheet.
        let firstDish = app.buttons.matching(identifier: "dish-row").firstMatch
        if firstDish.waitForExistence(timeout: 5) {
            firstDish.tap()
            pause(3)
            // Favorite it from the sheet.
            tapFirstMatch(app.buttons, labelPrefixes: ["Add "])
            pause(1.5)
            tapIfPresent(app.buttons["Close"])
            pause(1.5)
        }

        // Apply and clear the Vegan filter.
        tapIfPresent(app.buttons["Vegan"])
        pause(3)
        tapIfPresent(app.buttons["Vegan"])
        pause(1.5)

        // Scroll through the menu.
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        app.swipeDown()
        app.swipeDown()
        pause(1.5)

        // ── Campus: retail spots, menu sheet with dietary filter ──────────
        tapTab(app, "Campus")
        pause(3.5)
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
        tapFirstMatch(app.buttons, labelPrefixes: ["Show areas inside"])
        pause(2.5)
        app.swipeUp()
        pause(2)
        app.swipeDown()
        pause(1.5)

        // ── Settings (top-right gear): live appearance toggle ─────────────
        tapTab(app, "Eat")
        pause(2)
        tapIfPresent(app.buttons["Open settings"].firstMatch)
        pause(2.5)
        tapIfPresent(app.buttons["Dark appearance"])
        pause(2.5)
        tapIfPresent(app.buttons["Light appearance"])
        pause(2.5)
        tapIfPresent(app.buttons["System appearance"])
        pause(2)
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
    /// glass bar + Tab API; fall back to a global button query.
    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tabButton = app.tabBars.buttons[name]
        if tabButton.waitForExistence(timeout: 2), tabButton.isHittable {
            tabButton.tap()
        } else {
            tapIfPresent(app.buttons[name].firstMatch)
        }
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

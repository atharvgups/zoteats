import XCTest

/// Short App Store preview tour (about 20 seconds). Light mode, real UI, no
/// overlay text, no Gym. Breakfast / Lunch / Dinner pills, then Campus + Study.
final class AppPreviewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func testAppPreview() {
        let app = XCUIApplication()
        app.launch()

        pause(5)

        tapFirstMatch(app.buttons, labels: ["Lunch", "Breakfast"])
        pause(2.5)
        tapFirstMatch(app.buttons, labels: ["Dinner"])
        pause(2.5)

        tapTab(app, "Campus")
        pause(4)

        tapTab(app, "Study")
        pause(5)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

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
        let index: CGFloat
        switch name {
        case "Eat": index = 0
        case "Campus": index = 1
        case "Study": index = 2
        default: return
        }
        let x = (index + 0.5) / 3.0
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
}

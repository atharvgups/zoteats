import Foundation
import Testing
@testable import ZotEatsKit

@Suite("AppCanvasRecipe")
struct AppCanvasRecipeTests {
    @Test func sunriseIsWashedBlueToGoldToWhite() {
        let top = AppCanvasRecipe.sunrise[0]
        let mid = AppCanvasRecipe.sunrise[2]
        let bottom = AppCanvasRecipe.sunrise.last!
        #expect(top.blue > top.red)
        #expect(top.blue > top.green)
        #expect(mid.red > mid.blue)
        #expect(bottom.red > 0.96)
        #expect(bottom.green > 0.96)
        #expect(bottom.blue > 0.95)
    }

    @Test func sunsetIsNavyToAmberToBlack() {
        let top = AppCanvasRecipe.sunset[0]
        let mid = AppCanvasRecipe.sunset[2]
        let bottom = AppCanvasRecipe.sunset.last!
        #expect(top.blue > top.red)
        #expect(top.red + top.green + top.blue < 0.35)
        #expect(mid.red > mid.blue)
        #expect(bottom.red + bottom.green + bottom.blue < 0.15)
    }

    @Test func stopsAreNotBeigeOrSystemGray() {
        let parchment = (244 / 255.0, 242 / 255.0, 231 / 255.0)
        let systemGray = (242 / 255.0, 242 / 255.0, 247 / 255.0)
        for stop in AppCanvasRecipe.sunrise + AppCanvasRecipe.sunset {
            let parchmentMatch =
                abs(stop.red - parchment.0) < 0.01
                && abs(stop.green - parchment.1) < 0.01
                && abs(stop.blue - parchment.2) < 0.01
            let grayMatch =
                abs(stop.red - systemGray.0) < 0.01
                && abs(stop.green - systemGray.1) < 0.01
                && abs(stop.blue - systemGray.2) < 0.01
            #expect(!parchmentMatch)
            #expect(!grayMatch)
        }
    }
}

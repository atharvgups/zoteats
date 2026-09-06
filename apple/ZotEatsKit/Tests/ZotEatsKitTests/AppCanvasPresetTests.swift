import Foundation
import Testing
@testable import ZotEatsKit

@Suite("AppCanvasPreset")
struct AppCanvasPresetTests {
    @Test func labelsMatchDogfoodNames() {
        #expect(AppCanvasPreset.blueOnly.label == "Blue only")
        #expect(AppCanvasPreset.yellowOnly.label == "Yellow only")
        #expect(AppCanvasPreset.blueGold.label == "Blue → gold")
        #expect(AppCanvasPreset.goldBlue.label == "Gold → blue")
        #expect(AppCanvasPreset.mesh.label == "Blue + yellow mesh")
        #expect(AppCanvasPreset.hybrid.label == "Blue + yellow hybrid (1+2)")
        #expect(AppCanvasPreset.system.label == "System")
    }

    @Test func defaultIsBlueGold() {
        #expect(AppCanvasPreset.fallback == .blueGold)
        #expect(AppCanvasPreset.resolved(raw: nil) == .blueGold)
        #expect(AppCanvasPreset.resolved(raw: "nope") == .blueGold)
        #expect(AppCanvasPreset.resolved(raw: "hybrid") == .hybrid)
    }

    @Test func everyCaseIsListed() {
        #expect(AppCanvasPreset.allCases.count == 7)
    }

    @Test func blueGoldSunriseHasBlueThenGoldThenWhite() {
        let stops = AppCanvasPreset.blueGold.linearStops(dark: false)!
        let top = stops[0]
        let mid = stops[2]
        let bottom = stops.last!
        #expect(top.blue > top.red)
        #expect(mid.red > mid.blue)
        #expect(bottom.red > 0.96)
    }

    @Test func blueOnlyStaysBlue() {
        let top = AppCanvasPreset.blueOnly.linearStops(dark: false)![0]
        #expect(top.blue > top.red)
        #expect(AppCanvasPreset.blueOnly.linearStops(dark: true)![0].blue > 0.12)
    }

    @Test func yellowOnlyStaysGold() {
        let top = AppCanvasPreset.yellowOnly.linearStops(dark: false)![0]
        #expect(top.red > top.blue)
        #expect(top.green > top.blue)
    }

    @Test func goldBlueStartsGoldThenGoesBlue() {
        let sunrise = AppCanvasPreset.goldBlue.linearStops(dark: false)!
        #expect(sunrise[0].red > sunrise[0].blue)
        #expect(sunrise[2].blue > sunrise[2].red)
    }

    @Test func hybridHasBlueAndGoldPresent() {
        let sunrise = AppCanvasPreset.hybrid.linearStops(dark: false)!
        #expect(sunrise[0].blue > sunrise[0].red)
        #expect(sunrise[2].red > sunrise[2].blue)
        let sunset = AppCanvasPreset.hybrid.linearStops(dark: true)!
        #expect(sunset[0].blue > sunset[0].red)
        #expect(sunset[2].red > sunset[2].blue)
    }

    @Test func meshHasNineColors() {
        #expect(AppCanvasPreset.mesh.meshColors(dark: false)?.count == 9)
        #expect(AppCanvasPreset.mesh.meshColors(dark: true)?.count == 9)
        #expect(AppCanvasPreset.mesh.linearStops(dark: false) == nil)
    }

    @Test func systemHasNoGradient() {
        #expect(AppCanvasPreset.system.usesSystemFill)
        #expect(AppCanvasPreset.system.linearStops(dark: false) == nil)
        #expect(AppCanvasPreset.system.meshColors(dark: false) == nil)
    }
}

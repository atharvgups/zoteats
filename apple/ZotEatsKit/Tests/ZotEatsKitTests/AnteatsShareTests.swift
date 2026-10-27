import Foundation
import Testing
@testable import ZotEatsKit

@Suite("AnteatsShare")
struct AnteatsShareTests {
    @Test func usesLiveAppStoreListing() {
        #expect(AnteatsShare.appStoreURLString == "https://apps.apple.com/us/app/anteats/id6790896660")
        #expect(AnteatsShare.appStoreURL.host == "apps.apple.com")
        #expect(AnteatsShare.appStoreURL.path.contains("id6790896660"))
        #expect(AnteatsShare.appStoreURLString.contains("\u{2014}") == false)
        #expect(AnteatsShare.message.contains("\u{2014}") == false)
        #expect(AnteatsShare.shareText.contains(AnteatsShare.message))
        #expect(AnteatsShare.shareText.contains(AnteatsShare.appStoreURLString))
        #expect(AnteatsShare.rowTitle == "Share Anteats")
        #expect(AnteatsShare.rowSubtitle.contains("\u{2014}") == false)
    }
}

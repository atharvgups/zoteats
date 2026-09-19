import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DiningHubMenuURL")
struct DiningHubMenuURLTests {
    @Test func hallsOpenTheirOwnHubLocationPages() {
        #expect(
            DiningHubMenuURL.forHall("anteatery")?.absoluteString
                == "https://uci.mydininghub.com/en/location/the-anteatery"
        )
        #expect(
            DiningHubMenuURL.forHall("the-anteatery")?.absoluteString
                == "https://uci.mydininghub.com/en/location/the-anteatery"
        )
        #expect(
            DiningHubMenuURL.forHall("brandywine")?.absoluteString
                == "https://uci.mydininghub.com/en/location/brandywine"
        )
        #expect(
            DiningHubMenuURL.forHall("oasis")?.absoluteString
                == "https://uci.mydininghub.com/en/location/the-oasis-dining-hall"
        )
        #expect(
            DiningHubMenuURL.forHall("the-oasis-dining-hall")?.absoluteString
                == "https://uci.mydininghub.com/en/location/the-oasis-dining-hall"
        )
    }

    @Test func campusRetailUsesThePlaceUrlKey() {
        #expect(
            DiningHubMenuURL.forPlace(placeID: "zot-n-go-express-mesa-court")?.absoluteString
                == "https://uci.mydininghub.com/en/location/zot-n-go-express-mesa-court"
        )
        #expect(
            DiningHubMenuURL.forPlace(placeID: "  ") == nil
        )
    }

    @Test func oldCampusDishMenuPathsAreNotUsed() {
        let halls = ["anteatery", "brandywine", "oasis"].compactMap(DiningHubMenuURL.forHall)
        for url in halls {
            #expect(!url.absoluteString.contains("campusdish.com"))
            #expect(!url.absoluteString.contains("LocationsAndMenus"))
        }
    }
}

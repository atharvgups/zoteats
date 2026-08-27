import Foundation
import Testing
@testable import ZotEatsKit

@Suite("NextCampusOpenPick")
struct NextCampusOpenPickTests {
    private func place(
        id: String,
        name: String,
        openNow: Bool,
        opensAt: Int? = nil
    ) -> CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            category: "Coffee & Cafés",
            openNow: openNow,
            todayHours: openNow ? "8:00 AM – 5:00 PM" : nil,
            opensAtMinutes: opensAt
        )
    }

    @Test func openCountAndFavoriteLead() {
        let glance = NextCampusOpenPick.glance(
            places: [
                place(id: "px", name: "Panda", openNow: true),
                place(id: "sb", name: "Starbucks", openNow: true),
            ],
            favoriteIDs: ["sb"]
        )
        #expect(glance.openCount == 2)
        #expect(glance.favoriteOpenID == "sb")
        #expect(NextCampusOpenPick.headline(for: glance) == "2 spots open")
        #expect(NextCampusOpenPick.detail(for: glance) == "Starbucks")
    }

    @Test func closedUsesNextOpenHint() {
        let glance = NextCampusOpenPick.glance(
            places: [
                place(id: "sb", name: "Starbucks @ SC", openNow: false, opensAt: 7 * 60 + 30),
            ],
            favoriteIDs: []
        )
        #expect(glance.openCount == 0)
        #expect(glance.nextOpen?.placeID == "sb")
        #expect(NextCampusOpenPick.headline(for: glance) == "Nothing open")
        #expect(NextCampusOpenPick.detail(for: glance).contains("opens at"))
    }
}

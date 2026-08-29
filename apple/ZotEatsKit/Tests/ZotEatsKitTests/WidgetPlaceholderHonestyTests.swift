import Foundation
import Testing
@testable import ZotEatsKit

@Suite("WidgetPlaceholderHonesty")
struct WidgetPlaceholderHonestyTests {
    @Test func galleryNeverInventsBusyPercent() {
        #expect(WidgetPlaceholderHonesty.galleryHallOccupancy == nil)
        #expect(WidgetPlaceholderHonesty.galleryLibraryPercent == nil)
        #expect(FeatureFlags.diningHallOccupancy == false)
    }

    @Test func prefersSnapshotOverGalleryAndEmptyCache() {
        #expect(
            WidgetPlaceholderHonesty.source(hasSnapshot: true, isPreview: true) == .snapshot
        )
        #expect(
            WidgetPlaceholderHonesty.source(hasSnapshot: true, isPreview: false) == .snapshot
        )
        #expect(
            WidgetPlaceholderHonesty.source(hasSnapshot: false, isPreview: true) == .gallery
        )
        #expect(
            WidgetPlaceholderHonesty.source(hasSnapshot: false, isPreview: false) == .needsRefresh
        )
    }

    @Test func libraryPercentOnlyFromWaitzSnapshot() {
        #expect(
            WidgetPlaceholderHonesty.libraryPercent(waitzPercent: 8, source: .snapshot) == 8
        )
        #expect(
            WidgetPlaceholderHonesty.libraryPercent(waitzPercent: nil, source: .snapshot) == nil
        )
        #expect(
            WidgetPlaceholderHonesty.libraryPercent(waitzPercent: 8, source: .gallery) == nil
        )
        #expect(
            WidgetPlaceholderHonesty.libraryPercent(waitzPercent: 8, source: .needsRefresh) == nil
        )
    }
}

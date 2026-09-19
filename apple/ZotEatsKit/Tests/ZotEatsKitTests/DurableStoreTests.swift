import Foundation
import Testing
@testable import ZotEatsKit

@Suite("DurableStore — version-proof favorites")
struct DurableStoreTests {
    @Test func emptySuiteDoesNotHideStandardFavorites() {
        let testKey = "zoteats.test.fav.emptySuite"
        SharedDefaults.suite.removeObject(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: testKey)
        SharedDefaults.suite.set([String](), forKey: testKey)
        UserDefaults.standard.set(["Banana Berry Smoothie"], forKey: testKey)
        SharedDefaults.suite.synchronize()
        UserDefaults.standard.synchronize()

        let loaded = DurableStore.loadStringArray(key: testKey)
        #expect(loaded == ["Banana Berry Smoothie"])

        SharedDefaults.suite.removeObject(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    @Test func migratesVersionScopedKey() {
        let testKey = "zoteats.test.fav.versioned"
        SharedDefaults.suite.removeObject(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: testKey)
        let versioned = "\(testKey).1.0.323"
        UserDefaults.standard.set(["Grill Chicken"], forKey: versioned)
        UserDefaults.standard.synchronize()

        #expect(DurableStore.isVersionScopedKey(versioned, prefix: testKey))
        #expect(!DurableStore.isVersionScopedKey(testKey, prefix: testKey))

        let loaded = DurableStore.loadStringArray(key: testKey, legacyKeys: [versioned])
        #expect(loaded == ["Grill Chicken"])

        DurableStore.saveStringArray(loaded, key: testKey)
        #expect(DurableStore.loadStringArray(key: testKey) == ["Grill Chicken"])

        UserDefaults.standard.removeObject(forKey: versioned)
        SharedDefaults.suite.removeObject(forKey: testKey)
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    @Test func reviewerIDIsStableAcrossReads() {
        let first = DurableStore.reviewerID()
        let second = DurableStore.reviewerID()
        #expect(!first.isEmpty)
        #expect(first == second)
        #expect(!DurableStore.isVersionScopedKey(DurableStore.reviewerIDKey, prefix: "zoteats.reviewerID"))
    }
}

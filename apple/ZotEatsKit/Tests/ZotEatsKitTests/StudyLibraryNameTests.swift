import Foundation
import Testing
@testable import ZotEatsKit

@Suite("StudyLibraryName")
struct StudyLibraryNameTests {
    @Test func mapsWaitzScienceToGateway() {
        #expect(StudyLibraryName.display("Science Library") == "Gateway")
        #expect(StudyLibraryName.display("Sci Lib") == "Gateway")
        #expect(StudyLibraryName.display("Gateway Study Center") == "Gateway")
        #expect(StudyLibraryName.display("Langson Library") == "Langson")
        #expect(StudyLibraryName.display("Courtyard Study") == "Courtyard Study")
    }

    @Test func onlyLangsonAndGatewayCountAsStudyLibraries() {
        #expect(StudyLibraryName.isStudyLibrary("Langson Library"))
        #expect(StudyLibraryName.isStudyLibrary("Science Library"))
        #expect(StudyLibraryName.isStudyLibrary("Gateway Study Center"))
        #expect(!StudyLibraryName.isStudyLibrary("Student Center"))
        #expect(!StudyLibraryName.isStudyLibrary("Grunigen Medical Library"))
        #expect(!StudyLibraryName.isStudyLibrary("Multimedia Resources Center"))
        #expect(!StudyLibraryName.isStudyLibrary("Courtyard Study Lounge"))
        #expect(!StudyLibraryName.isStudyLibrary("ARC"))
    }

    @Test func studyLibrariesDropsExtraWaitzRows() {
        let langson = BusynessPoint(
            id: 1, name: "Langson Library", category: "Library",
            count: nil, capacity: nil, percent: 10, level: .notBusy,
            isOpen: true, hoursSummary: nil, updatedAt: Date(), subLocations: nil
        )
        let grunigen = BusynessPoint(
            id: 2, name: "Grunigen Medical Library", category: "Library",
            count: nil, capacity: nil, percent: 1, level: .notBusy,
            isOpen: true, hoursSummary: nil, updatedAt: Date(), subLocations: nil
        )
        let studentCenter = BusynessPoint(
            id: 3, name: "Student Center", category: "Campus",
            count: nil, capacity: nil, percent: nil, level: .unknown,
            isOpen: true, hoursSummary: "7:00 AM – midnight", updatedAt: Date(),
            subLocations: nil
        )
        let kept = StudyLibraryName.studyLibraries(from: [langson, grunigen, studentCenter])
        #expect(kept.map(\.name) == ["Langson Library"])
    }
}

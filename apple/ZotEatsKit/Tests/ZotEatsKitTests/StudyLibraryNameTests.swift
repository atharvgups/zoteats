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
}

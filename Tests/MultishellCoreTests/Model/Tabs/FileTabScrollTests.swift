import Foundation
import Testing

@testable import MultishellCore

struct FileTabScrollTests {
  @Test func aScrollSavedByAnEarlierBuildKeepsWhichSidesLineItWas() throws {
    let json = #"{ "line": 12, "isHEADsLine": true, "rowsFromLine": 0.5, "x": 3 }"#

    let scroll = try decodeJSON(FileTabScroll.self, json)

    #expect(scroll == FileTabScroll(line: 12, isCommittedLine: true, rowsFromLine: 0.5, x: 3))
  }
}

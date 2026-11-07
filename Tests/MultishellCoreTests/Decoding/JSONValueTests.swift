import Foundation
import Testing

@testable import MultishellCore

@Suite
struct JSONValueTests {
  @Test func anIntegerPastIntsRangeIsWrittenBackAsRead() throws {
    let read = try JSONDecoder().decode(JSONValue.self, from: Data("12345678901234567890".utf8))

    let written = String(decoding: try JSONEncoder().encode(read), as: UTF8.self)

    #expect(written == "12345678901234567890")
  }
}

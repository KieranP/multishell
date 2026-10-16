import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct TextDecodingTests {
  @Test func utf8IsReadAsItIsAndAnEmptyFileIsText() {
    #expect(TextDecoding.decode(Data("naïve\n".utf8))?.text == "naïve\n")
    #expect(TextDecoding.decode(Data())?.encoding == .utf8)
  }

  @Test func latin1IsGuessedAsATextEditorWould() throws {
    let decoded = try #require(TextDecoding.decode(Data([0x63, 0x61, 0x66, 0xE9, 0x0A])))
    #expect(decoded.text == "café\n")
  }

  @Test func aZeroByteEarlyOnIsBinary() {
    #expect(TextDecoding.decode(Data([0x89, 0x50, 0x00, 0x01])) == nil)
  }
}

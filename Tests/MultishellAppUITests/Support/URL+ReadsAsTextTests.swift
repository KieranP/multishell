import Foundation
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite
struct URLReadsAsTextTests {
  private func file(holding bytes: Data) throws -> URL {
    let file = Scratch.path("reads-as-text")
    try bytes.write(to: file)
    return file
  }

  @Test func utf8WithNoZeroByteReadsAsTextAndAnEmptyFileToo() throws {
    for bytes in [Data("é fn main() {}".utf8), Data()] {
      let file = try file(holding: bytes)
      defer { Scratch.remove(file) }
      #expect(file.readsAsText())
    }
  }

  @Test func aZeroByteOrAnInvalidSequenceIsNotText() throws {
    for bytes in [Data([0x61, 0x00, 0x62]), Data([0x25, 0xE2, 0xE3, 0xCF])] {
      let file = try file(holding: bytes)
      defer { Scratch.remove(file) }
      #expect(file.readsAsText() == false)
    }
  }

  @Test func aCharacterCutAtTheEndOfWhatIsReadStillReadsAsText() throws {
    let euroSigns = Data(String(repeating: "€", count: 3000).utf8)
    let file = try file(holding: euroSigns)
    defer { Scratch.remove(file) }

    #expect(euroSigns.count > 8192 && !8192.isMultiple(of: 3), "the read ends mid-character")
    #expect(file.readsAsText())
  }

  @Test func binaryThatEndsWhereTheReadStopsIsNotText() throws {
    let binary = Data("MZ".utf8) + Data(repeating: 0xFF, count: 8190)
    let file = try file(holding: binary)
    defer { Scratch.remove(file) }

    #expect(file.readsAsText() == false)
  }

  @Test func aFileThatCannotBeOpenedIsNotText() {
    #expect(Scratch.path("missing").readsAsText() == false)
  }
}

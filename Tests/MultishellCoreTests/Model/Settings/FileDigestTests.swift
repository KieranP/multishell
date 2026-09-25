import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// A stored trust answer holds this form, so a change to it re-asks every question.
@Suite
struct FileDigestTests {
  @Test func theKnownVectorsHold() {
    #expect(
      FileDigest.sha256(of: Data())
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    #expect(
      FileDigest.sha256(of: Data("abc".utf8))
        == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    #expect(
      FileDigest.sha256(of: Data([0x00, 0x01, 0xff, 0xfe]))
        == "5e90fe977790507860b03456633c9ad88ea951cd8a6620d3e37ca43c160c15ae",
      "bytes, not text")
  }

  /// What the app actually hashes: the bytes of a `.multishell.json`.
  @Test func aFilesBytesHashToTheSameDigestAsItsContents() throws {
    let directory = try Scratch.directory("digest")
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("settings.json")
    try #"{ "postCreateHook": "npm ci" }"#.appending("\n")
      .write(to: file, atomically: true, encoding: .utf8)
    #expect(
      FileDigest.sha256(of: try Data(contentsOf: file))
        == "118fb7b77111f18f38c287829196fa2865c274081cfb97a549042e5f0131d32c")
  }
}

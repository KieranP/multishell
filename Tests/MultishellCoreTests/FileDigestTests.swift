import Foundation
import Testing

@testable import MultishellCore

/// The core hashes its own bytes, so the vectors are checked here rather
/// than taken on trust: the padding around a block boundary is where an
/// implementation of this goes wrong.
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

  /// 55 bytes is the last length whose padding fits its own block, 56 the
  /// first that takes another, and 64 an exact block.
  @Test func theLengthsAroundABlockBoundaryHash() {
    func digest(ofAs count: Int) -> String {
      FileDigest.sha256(of: Data(String(repeating: "a", count: count).utf8))
    }
    #expect(digest(ofAs: 55) == "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318")
    #expect(digest(ofAs: 56) == "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a")
    #expect(digest(ofAs: 64) == "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb")
    #expect(digest(ofAs: 65) == "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0")
    #expect(
      digest(ofAs: 1000) == "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
  }

  /// What the app actually hashes: the bytes of a `.multishell.json`.
  @Test func aFilesBytesHashToTheSameDigestAsItsContents() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("digest-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("settings.json")
    try #"{ "postCreateHook": "npm ci" }"#.appending("\n")
      .write(to: file, atomically: true, encoding: .utf8)
    #expect(
      FileDigest.sha256(of: try Data(contentsOf: file))
        == "118fb7b77111f18f38c287829196fa2865c274081cfb97a549042e5f0131d32c")
  }
}

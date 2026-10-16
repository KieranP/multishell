import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct URLIsOnLocalVolumeTests {
  @Test func aScratchDirectoryIsLocalAndAMissingPathCountsAsLocal() throws {
    let root = try Scratch.directory("volume")
    defer { Scratch.remove(root) }

    #expect(root.isOnLocalVolume)
    #expect(root.appendingPathComponent("absent").isOnLocalVolume)
  }
}

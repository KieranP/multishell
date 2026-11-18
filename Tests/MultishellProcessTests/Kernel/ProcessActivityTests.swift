import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessActivityTests {
  private static let writeSize = 8 << 20

  private var ownPID: Int32 { ProcessInfo.processInfo.processIdentifier }

  @Test func bytesWrittenAndSyncedToDiskCountAsWritten() throws {
    let directory = try Scratch.directory("activity")
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("written")
    FileManager.default.createFile(atPath: file.path, contents: nil)
    let before = try #require(ProcessActivity.of(ownPID))
    let handle = try FileHandle(forWritingTo: file)
    try handle.write(contentsOf: Data(repeating: 1, count: Self.writeSize))
    try handle.synchronize()
    try handle.close()
    let after = try #require(ProcessActivity.of(ownPID))

    #expect(after.diskBytesWritten >= before.diskBytesWritten + UInt64(Self.writeSize / 2))
  }

  @Test func thePeakFootprintIsNeverBelowTheFootprintNow() throws {
    let footprint = try #require(KernelResourceUsage.of(ownPID)).footprint
    let activity = try #require(ProcessActivity.of(ownPID))

    #expect(activity.peakFootprint >= footprint)
  }

  @Test func aPIDNothingHoldsHasNoActivity() {
    #expect(ProcessActivity.of(deadPID()) == nil)
  }
}

import CoreServices
import Foundation
import Synchronization
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct FileEventBatchReceiverTests {
  @Test func anEventCoalescedOverASubtreeCountsEveryWatchedDirectoryAsChanged() throws {
    let root = try Scratch.directory("watched")
    defer { Scratch.remove(root) }
    let watched = WatchedDirectories([root])
    let real = try #require(watched.realPaths.first)
    let reported = Mutex<[URL]>([])
    let receiver = FileEventBatchReceiver(watched: watched) { urls in
      reported.withLock { $0 += urls }
    }

    receiver.receive(
      ["\(real)/src"],
      flags: [FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs)],
    )

    #expect(reported.withLock { $0 } == watched.directories)
  }
}

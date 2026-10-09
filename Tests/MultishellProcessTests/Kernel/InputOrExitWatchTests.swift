import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct InputOrExitWatchTests {
  @Test func aWriterAlreadyGoneIsReportedAsExitedAtOnce() throws {
    let pipe = Pipe()
    let watch = try #require(
      InputOrExitWatch(descriptor: pipe.fileHandleForReading.fileDescriptor, pid: deadPID())
    )
    #expect(watch.next() == .exited)
  }

  @Test func inputFromALiveWriterIsReportedAndDrainedWithoutWaiting() throws {
    let pipe = Pipe()
    let watch = try #require(
      InputOrExitWatch(
        descriptor: pipe.fileHandleForReading.fileDescriptor,
        pid: ProcessInfo.processInfo.processIdentifier,
      )
    )
    pipe.fileHandleForWriting.write(Data("command-started 1 ls\n".utf8))

    #expect(watch.next() == .input)
    #expect(watch.drain() == Data("command-started 1 ls\n".utf8))
  }

  @Test func theWritersExitEndsTheWaitWhileThePipeIsStillHeldOpen() throws {
    let pipe = Pipe()
    let writer = Process()
    writer.executableURL = URL(fileURLWithPath: "/bin/sleep")
    writer.arguments = ["0.2"]
    try writer.run()
    let watch = try #require(
      InputOrExitWatch(
        descriptor: pipe.fileHandleForReading.fileDescriptor,
        pid: writer.processIdentifier,
      )
    )

    #expect(watch.next() == .exited)
    writer.waitUntilExit()
  }

  @Test func noProcessIdGivesNoWatch() {
    #expect(InputOrExitWatch(descriptor: 0, pid: 0) == nil)
  }
}

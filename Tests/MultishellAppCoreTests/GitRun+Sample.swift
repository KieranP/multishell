import Foundation

@testable import MultishellGitKit
@testable import MultishellProcess

extension GitRun {
  static func sample(
    _ command: String = "status", milliseconds: Int = 150, in path: String = "/w",
    peakMemory: UInt64? = nil, pid: Int32 = 1, cpuTime: Duration = .zero
  ) -> GitRun {
    GitRun(
      command: command, directory: URL(fileURLWithPath: path),
      duration: .milliseconds(milliseconds),
      exitUsage: peakMemory.map { ExitUsage(pid: pid, peakFootprint: $0, cpuTime: cpuTime) })
  }
}

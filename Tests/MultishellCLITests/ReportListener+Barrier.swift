import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

extension ReportListener {
  /// Every line read once a report sent now arrives, which is last: anything
  /// the helper had sent before it is on the line ahead of it.
  func linesUpToABarrier() async throws -> [String] {
    let barrier = try await HelperBinary.run(
      ["state", "done", "--agent", "opencode"],
      environment: ["MULTISHELL_SOCKET": path.path],
    )
    #expect(barrier.succeeded, "\(barrier.standardError)")
    let barrierArrived = { [recorder] in
      let last = SessionStateReport.parse(recorder.received.last ?? "")
      return last?.state == .done && last?.agentID == "opencode"
    }
    try await waitUntil(barrierArrived)
    try #require(barrierArrived())
    return recorder.received
  }
}

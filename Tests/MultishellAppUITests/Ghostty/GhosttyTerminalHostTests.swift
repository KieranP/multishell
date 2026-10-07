import Foundation
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttyTerminalHostTests {
  @Test func aSessionReportsNothingOnceClosed() throws {
    let host = GhosttyTerminalHost(runtimeOwner: GhosttyRuntimeOwner(readBase: { "" }))
    let delegate = RecordingTerminalHostDelegate()
    host.delegate = delegate
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
      title: "Sleep", command: ["/bin/sleep", "60"])
    try host.open(session)
    let view = try #require(host.view(for: session.id) as? GhosttySurfaceView)

    host.close(session.id)
    view.receive(.retitled("late"))
    view.receive(.bell)
    view.receive(.commandFinished(exitCode: 0))

    #expect(delegate.reports.isEmpty)
  }
}

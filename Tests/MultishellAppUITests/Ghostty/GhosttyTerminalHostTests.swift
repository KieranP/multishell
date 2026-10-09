import AppKit
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttyTerminalHostTests {
  @Test func aSessionReportsNothingOnceClosed() throws {
    let host = GhosttyTerminalHost(lazyRuntime: LazyGhosttyRuntime(readBase: { "" }))
    let delegate = RecordingTerminalHostDelegate()
    host.delegate = delegate
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
      title: "Sleep",
      command: ["/bin/sleep", "60"],
    )
    try host.open(session)
    let view = try #require(host.view(for: session.id) as? GhosttySurfaceView)

    host.close(session.id)
    view.receive(.retitled("late"))
    view.receive(.bell)
    view.receive(.commandFinished(exitCode: 0))

    #expect(delegate.reports.isEmpty)
  }

  /// Awaits rather than settling the run loop: `close` frees each surface in
  /// a main-queue block, which a nested run loop inside a test never drains.
  @Test func closedSessionsLetTheirSurfaceViewsGo() async throws {
    let host = GhosttyTerminalHost(lazyRuntime: LazyGhosttyRuntime(readBase: { "" }))
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    let window = OffscreenWindow.holding(container, deferred: false)
    var isReleased: [() -> Bool] = []
    try autoreleasepool {
      for index in 0..<5 {
        let session = TerminalSession(
          worktreeID: "/w",
          workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
          title: "Sleep \(index)",
          command: ["/bin/sleep", "60"],
        )
        try host.open(session)
        let view = try #require(host.view(for: session.id))
        view.frame = container.bounds
        container.addSubview(view)
        isReleased.append { [weak view] in view == nil }
        host.close(session.id)
      }
    }
    for _ in 0..<100 where !isReleased.allSatisfy({ $0() }) {
      try await Task.sleep(for: .milliseconds(20))
    }

    withExtendedLifetime(window) {
      let releasedCount = isReleased.filter { $0() }.count
      #expect(releasedCount == 5)
    }
  }
}

import AppKit
import TestScratch
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttyTerminalHostTests {
  private func hostWithDelegate() -> (GhosttyTerminalHost, FakeTerminalHostDelegate) {
    let host = GhosttyTerminalHost(lazyRuntime: LazyGhosttyRuntime(readBase: { "" }))
    let delegate = FakeTerminalHostDelegate()
    host.delegate = delegate
    return (host, delegate)
  }

  private func openSleepingSession(
    in host: GhosttyTerminalHost,
    at directory: URL,
  ) throws -> (TerminalSession, GhosttySurfaceView) {
    let session = TerminalSession(
      worktreeID: "/w",
      workingDirectory: directory,
      title: "Sleep",
      command: ["/bin/sleep", "60"],
    )
    try host.open(session)
    return (session, try #require(host.view(for: session.id) as? GhosttySurfaceView))
  }

  private func textFile(named name: String, in directory: URL) throws -> URL {
    let file = directory.appendingPathComponent(name)
    try "notes".write(to: file, atomically: true, encoding: .utf8)
    return file
  }

  @Test func aSessionReportsNothingOnceClosed() throws {
    let (host, delegate) = hostWithDelegate()
    let (session, view) = try openSleepingSession(
      in: host,
      at: URL(fileURLWithPath: NSTemporaryDirectory()),
    )

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
      for _ in 0..<5 {
        let (session, view) = try openSleepingSession(
          in: host,
          at: URL(fileURLWithPath: NSTemporaryDirectory()),
        )
        view.frame = container.bounds
        container.addSubview(view)
        isReleased.append { [weak view] in view == nil }
        host.close(session.id)
      }
    }
    try await waitUntil({ isReleased.allSatisfy { $0() } }, seconds: 2)

    withExtendedLifetime(window) {
      let releasedCount = isReleased.filter { $0() }.count
      #expect(releasedCount == 5)
    }
  }

  @Test func aTextFilesLinkClickedInAPaneGoesToTheDelegateAfterLibghosttyReturns() async throws {
    let directory = try Scratch.directory("link-click")
    defer { Scratch.remove(directory) }
    let file = try textFile(named: "notes.txt", in: directory)
    let (host, delegate) = hostWithDelegate()
    let (session, view) = try openSleepingSession(in: host, at: directory)
    defer { host.close(session.id) }

    view.receive(.linkClicked(file.absoluteString))
    #expect(delegate.editedFiles.isEmpty, "inside libghostty's click, which holds the pane's lock")
    try await waitUntil { !delegate.editedFiles.isEmpty }

    #expect(delegate.editedFiles == [URL(filePath: file.path)])
  }

  @Test func anOsc8LinkToATextFileGoesToTheDelegateToEdit() async throws {
    let directory = try Scratch.directory("hyperlink")
    defer { Scratch.remove(directory) }
    let file = try textFile(named: "notes.txt", in: directory)
    let (host, delegate) = hostWithDelegate()
    let (session, view) = try openSleepingSession(in: host, at: directory)
    defer { host.close(session.id) }

    view.receive(.hyperlinkClicked(file.absoluteString))
    try await waitUntil { !delegate.editedFiles.isEmpty }

    #expect(delegate.editedFiles == [URL(filePath: file.path)])
  }

  @Test func aRelativeLinkResolvesInTheDirectoryThePaneLastReported() async throws {
    let started = try Scratch.directory("link-started")
    defer { Scratch.remove(started) }
    let moved = try Scratch.directory("link-moved")
    defer { Scratch.remove(moved) }
    let inStarted = try textFile(named: "notes.txt", in: started)
    let inMoved = try textFile(named: "notes.txt", in: moved)
    let (host, delegate) = hostWithDelegate()
    let (session, view) = try openSleepingSession(in: host, at: started)
    defer { host.close(session.id) }

    view.receive(.directoryReported(moved.path))
    view.receive(.linkClicked("notes.txt"))
    try await waitUntil { delegate.editedFiles.count == 1 }
    view.receive(.directoryReported(nil))
    view.receive(.linkClicked("notes.txt"))
    try await waitUntil { delegate.editedFiles.count == 2 }

    #expect(delegate.editedFiles.map(\.path) == [inMoved.path, inStarted.path])
  }

  @Test func filesPastedInAPaneAreHandedToTheDelegateForItsSessionUntilItCloses() throws {
    let (host, delegate) = hostWithDelegate()
    let (session, view) = try openSleepingSession(
      in: host,
      at: URL(fileURLWithPath: NSTemporaryDirectory()),
    )
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let file = URL(fileURLWithPath: "/tmp/shot.png")
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([file as NSURL])
    view.pasteboard = pasteboard
    view.dropsDirectory = drops
    delegate.textForPastedFiles = "@/tmp/shot.png"

    view.paste(nil)
    host.close(session.id)
    view.paste(nil)

    #expect(delegate.pastedFiles.map(\.files) == [[file]])
    #expect(delegate.pastedFiles.map(\.id) == [session.id])
  }

  @Test func aLinkJudgedAfterItsPaneClosedOpensNothingAndLaterClicksStillDo() async throws {
    let directory = try Scratch.directory("link-closed")
    defer { Scratch.remove(directory) }
    let first = try textFile(named: "first.txt", in: directory)
    let second = try textFile(named: "second.txt", in: directory)
    let (host, delegate) = hostWithDelegate()
    let (closing, closingView) = try openSleepingSession(in: host, at: directory)
    let (staying, stayingView) = try openSleepingSession(in: host, at: directory)
    defer { host.close(staying.id) }

    closingView.receive(.linkClicked(first.path))
    host.close(closing.id)
    stayingView.receive(.linkClicked(second.path))
    try await waitUntil { !delegate.editedFiles.isEmpty }

    #expect(delegate.editedFiles == [URL(filePath: second.path)])
  }
}

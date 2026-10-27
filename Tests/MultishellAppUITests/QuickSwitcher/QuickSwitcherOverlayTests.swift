import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct QuickSwitcherOverlayTests {
  private struct Pane: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
  }

  private static func fortyCommandsShown(
    height: Double = 600
  ) throws -> (ModelHarness, NSScrollView) {
    let models = ModelHarness()
    let commands = (1...40).map { number in
      PlatformMenuItem(path: ["Edit", "Command \(number)"], isEnabled: true, isChecked: false)
    }
    models.model.quickSwitcher = QuickSwitcherState(scope: .commands, commands: commands)
    let frame = NSRect(x: 0, y: 0, width: 800, height: height)
    let host = NSHostingView(rootView: QuickSwitcherLayer(model: models.model))
    host.frame = frame
    _ = OffscreenWindow.holding(host, rect: frame, deferred: false)
    OffscreenWindow.settle(until: { Self.isScrollable(host) }, within: 2)
    let scrollView = try #require(host.descendants(of: NSScrollView.self).first)
    return (models, scrollView)
  }

  private static func isScrollable(_ host: NSView) -> Bool {
    guard let scrollView = host.descendants(of: NSScrollView.self).first,
      let document = scrollView.documentView
    else { return false }
    return document.frame.height > scrollView.contentView.bounds.height
  }

  @Test func aPaneUnderTheSwitcherIsNotWhatAClickOnItOrBesideItFinds() throws {
    let models = ModelHarness()
    models.addPrimaryWorktree()
    models.model.quickSwitcher = QuickSwitcherState(scope: .worktrees, commands: [])
    let pane = NSView()
    let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
    let host = NSHostingView(
      rootView: ZStack {
        Pane(view: pane)
        QuickSwitcherLayer(model: models.model)
      }
    )
    host.frame = frame
    let window = OffscreenWindow.holding(host, rect: frame, deferred: false)
    OffscreenWindow.settle(
      until: { (host.descendants(of: NSTextField.self).first?.frame.width ?? 0) > 0 },
      within: 2,
    )

    for point in [NSPoint(x: 400, y: 460), NSPoint(x: 400, y: 50)] {
      let found = try #require(GhosttyPaneEventMonitor.view(at: point, in: window))
      #expect(!found.isDescendant(of: pane), "at \(point)")
    }
  }

  @Test func typingScrollsBackToTheTopThoughTheFirstRowStaysSelected() throws {
    let (models, scrollView) = try Self.fortyCommandsShown()
    let top = scrollView.contentView.bounds.origin.y
    scrollView.contentView.scroll(to: CGPoint(x: 0, y: top + 200))
    #expect(scrollView.contentView.bounds.origin.y != top)

    models.model.setQuickSwitcherText("c")
    OffscreenWindow.settle(until: { scrollView.contentView.bounds.origin.y == top }, within: 2)

    #expect(scrollView.contentView.bounds.origin.y == top)
  }

  @Test func arrowsBackUpToTheFirstRowShowItsSectionTitle() throws {
    let (models, scrollView) = try Self.fortyCommandsShown()
    let top = scrollView.contentView.bounds.origin.y
    for _ in 1...30 { models.model.moveQuickSwitcherSelection(.next) }
    OffscreenWindow.settle(until: { scrollView.contentView.bounds.origin.y != top }, within: 2)
    #expect(scrollView.contentView.bounds.origin.y != top)

    for _ in 1...30 { models.model.moveQuickSwitcherSelection(.previous) }
    OffscreenWindow.settle(until: { scrollView.contentView.bounds.origin.y == top }, within: 2)

    #expect(scrollView.contentView.bounds.origin.y == top)
  }

  @Test func inTheShortestWindowTheListEndsInsideIt() throws {
    let (_, scrollView) = try Self.fortyCommandsShown(height: 420)

    let inWindow = scrollView.convert(scrollView.bounds, to: nil)

    #expect(inWindow.minY >= 0)
  }
}

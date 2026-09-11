import AppKit
import SwiftUI
import Testing

@testable import Multishell

/// Every settings page laid out at the width its window gives it, in a
/// window that is never ordered in: no screen, and none of the permissions
/// driving one would ask for.
///
/// Both settings windows are fixed at `SettingsView.windowSize`, so a page
/// taller than that is reachable only by scrolling a form the user has no
/// reason to think scrolls. Adding rows is how that happens, and adding rows
/// is cheap. The two pages that already scroll say so below, which is what
/// makes this catch the next one.
///
/// The full height is the page's to use: measured here, the tab content is
/// given the whole 480 and the band takes none of it. That was worth
/// checking, since the band is invisible to everything else in this file.
///
/// Agent settings is left out, not fixed: its `onAppear` refresh reads the
/// machine, so the page is as tall as this developer has agents, and a test
/// that measured it would be measuring a laptop. It also overflows, which is
/// in known-gaps.md. Appearance stays in: its font list is the machine's too,
/// but a picker is one row however many fonts are in it.
///
/// The bound is absolute rather than a margin, and three of the project
/// pages sit within 70pt of it. So this is likely the first test to fail on
/// a macOS that grows a grouped form's rows, and that failure would be
/// correct: the window is fixed, so the page really would overflow.
///
/// Two things this cannot see. The tab band itself: SwiftUI draws it outside
/// the AppKit hierarchy, absent from both a rendered bitmap and a measured
/// size, so whether six tab items fit in 560 stays a question for the screen.
/// And width: a minimum-size measurement reports the width at which text
/// stops wrapping, not the width at which a control is cut off, so it reads
/// 744 for the Notifications page whose caption is meant to wrap. Both are in
/// known-gaps.md.
@Suite @MainActor
struct SettingsPageSizeTests {
  @Test func noSettingsPageIsTallerThanTheWindowItOpensIn() {
    for page in Self.pages(of: ModelHarness()) where !page.scrolls {
      let needed = page.view.smallestHeight(atWidth: SettingsView.windowSize.width)
      #expect(
        needed <= SettingsView.windowSize.height,
        "\(page.name) needs \(needed)pt, the window is \(SettingsView.windowSize.height)pt")
    }
  }

  private struct Page {
    let name: String
    let view: AnyView
    /// Taller than the window on purpose, or at least knowingly. Everything
    /// else has to fit, a new page included.
    var scrolls = false
  }

  /// Both windows' tabs, app-wide and per-project. The two windows are the
  /// same size on purpose, so a page added to either is held to one bound.
  private static func pages(of harness: ModelHarness) -> [Page] {
    let model = harness.model
    let project = harness.project
    return [
      Page(name: "General", view: AnyView(GeneralSettingsTab(model: model))),
      Page(name: "Worktrees", view: AnyView(WorktreeSettingsTab(model: model))),
      Page(name: "Terminal", view: AnyView(TerminalSettingsTab(model: model))),
      Page(name: "Notifications", view: AnyView(NotificationSettingsTab(model: model))),
      Page(name: "Appearance", view: AnyView(AppearanceSettingsTab(model: model))),
      // Overflows by about 100pt. Whether that is wanted is in known-gaps.md.
      Page(
        name: "Project General", view: AnyView(ProjectGeneralTab(model: model, project: project)),
        scrolls: true),
      Page(
        name: "Project Worktrees",
        view: AnyView(ProjectWorktreesTab(model: model, project: project))),
      // Six monospaced editors: no window this size was ever going to hold it.
      Page(
        name: "Project Hooks", view: AnyView(ProjectHooksTab(model: model, project: project)),
        scrolls: true),
      Page(
        name: "Project Terminal",
        view: AnyView(ProjectTerminalTab(model: model, project: project))),
      Page(
        name: "Project Agents", view: AnyView(ProjectAgentTab(model: model, project: project))),
    ]
  }
}

extension View {
  /// The height this view needs to show everything at `width`.
  ///
  /// The window is not decoration: hosted without one the same view measures
  /// a few points taller, so the figure would not be the one the user gets.
  @MainActor
  fileprivate func smallestHeight(atWidth width: CGFloat) -> CGFloat {
    let host = NSHostingView(rootView: frame(width: width))
    host.sizingOptions = [.minSize, .intrinsicContentSize]
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    return host.intrinsicContentSize.height
  }
}

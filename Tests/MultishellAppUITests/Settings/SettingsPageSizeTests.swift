import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppUI

/// Agent settings' Hooks part is left out because its height is the developer's agent count; the
/// exemptions and what this cannot see are in Docs/develop/tests.md and build.md.
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
      Page(name: "Agents, Agent", view: AnyView(AgentSettingsTab(model: model, part: .agent))),
      Page(name: "Notifications", view: AnyView(NotificationSettingsTab(model: model))),
      Page(name: "Appearance", view: AnyView(AppearanceSettingsTab(model: model))),
      Page(
        name: "Project General", view: AnyView(ProjectGeneralTab(model: model, project: project))),
      Page(
        name: "Project Worktrees",
        view: AnyView(ProjectWorktreesTab(model: model, project: project))),
      Page(
        name: "Project Hooks, Create",
        view: AnyView(ProjectHooksTab(model: model, project: project, stage: .create))),
      Page(
        name: "Project Hooks, Create, a repository file asking for trust",
        view: AnyView(
          ProjectHooksTab(model: model, project: askingForTrust(project), stage: .create))),
      Page(
        name: "Project Hooks, Delete",
        view: AnyView(ProjectHooksTab(model: model, project: project, stage: .delete))),
      Page(
        name: "Project Hooks, Environment",
        view: AnyView(ProjectHooksTab(model: model, project: project, stage: .environment))),
      Page(
        name: "Project Terminal",
        view: AnyView(ProjectTerminalTab(model: model, project: project))),
      Page(
        name: "Project Agents", view: AnyView(ProjectAgentTab(model: model, project: project))),
    ]
  }
}

/// The tallest the Create group gets: the trust section stands above it.
@MainActor
private func askingForTrust(_ project: Project) -> Project {
  let shared = SharedProjectSettings(preCreateHook: "make setup", postCreateHook: "npm ci")
  var asking = project
  asking.sharedSettings = SharedSettingsSnapshot(
    asWritten: shared, confined: shared, hasBeenRead: true)
  return asking
}

extension View {
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

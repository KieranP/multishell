import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

/// Agent settings' Hooks part is left out because its height is the developer's agent count; the
/// exemptions and what this cannot see are in Docs/develop/tests.md and build.md.
@Suite @MainActor
struct SettingsWindowSizeTests {
  @Test func noSettingsPageIsTallerThanTheWindowItOpensIn() {
    for page in Self.pages(of: ModelHarness()) {
      let needed = OffscreenHost.read(
        page.view, atWidth: SettingsWindowSize.fixed.width,
        windowSize: CGSize(width: 10, height: 10),
        sizingOptions: [.minSize, .intrinsicContentSize]
      ) { $0.intrinsicContentSize.height }
      #expect(
        needed <= SettingsWindowSize.fixed.height,
        "\(page.name) needs \(needed)pt, the window is \(SettingsWindowSize.fixed.height)pt")
    }
  }

  private struct Page {
    let name: String
    let view: AnyView
  }

  /// Both windows' tabs, app-wide and per-project. The two windows are the
  /// same size on purpose, so a page added to either is held to one bound.
  private static func pages(of harness: ModelHarness) -> [Page] {
    let model = harness.model
    let project = harness.project
    return [
      Page(name: "General", view: AnyView(GeneralSettingsPage(model: model))),
      Page(name: "Worktrees", view: AnyView(WorktreesSettingsPage(model: model))),
      Page(name: "Terminal", view: AnyView(TerminalSettingsPage(model: model))),
      Page(name: "Agents, Agent", view: AnyView(AgentsSettingsPage(model: model, part: .agent))),
      Page(name: "Notifications", view: AnyView(NotificationsSettingsPage(model: model))),
      Page(name: "Appearance", view: AnyView(AppearanceSettingsPage(model: model))),
      Page(
        name: "Project General", view: AnyView(ProjectGeneralPage(model: model, project: project))),
      Page(
        name: "Project Worktrees",
        view: AnyView(ProjectWorktreesPage(model: model, project: project))),
      Page(
        name: "Project Hooks, Create",
        view: AnyView(ProjectHooksPage(model: model, project: project, part: .create))),
      Page(
        name: "Project Hooks, Create, a repository file asking for trust",
        view: AnyView(
          ProjectHooksPage(model: model, project: project.askingForTrust(), part: .create))),
      Page(
        name: "Project Hooks, Delete",
        view: AnyView(ProjectHooksPage(model: model, project: project, part: .delete))),
      Page(
        name: "Project Hooks, Environment",
        view: AnyView(ProjectHooksPage(model: model, project: project, part: .environment))),
      Page(
        name: "Project Terminal",
        view: AnyView(ProjectTerminalPage(model: model, project: project))),
      Page(
        name: "Project Agents", view: AnyView(ProjectAgentsPage(model: model, project: project))),
    ]
  }
}

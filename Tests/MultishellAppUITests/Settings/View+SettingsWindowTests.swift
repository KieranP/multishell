import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

/// Agents' Agent Hooks part is left out because its height is the developer's agent count; the
/// exemptions and what this cannot see are in Docs/develop/tests.md and build.md.
@Suite @MainActor
struct ViewSettingsWindowTests {
  private struct Page {
    let name: String
    let view: AnyView
  }

  /// Every page and part, All Projects' and a project's, each shown in the one
  /// detail column, so a page added to either is held to one bound.
  private static func pages(of harness: ModelHarness) -> [Page] {
    let model = harness.model
    let project = harness.project
    return [
      Page(name: "General", view: AnyView(AppGeneralPage(model: model))),
      Page(name: "Worktrees", view: AnyView(AppWorktreesPage(model: model))),
      Page(name: "Terminal", view: AnyView(AppTerminalPage(model: model))),
      Page(name: "Agents, Agent settings", view: AnyView(AppAgentSettingsPage(model: model))),
      Page(name: "Notifications", view: AnyView(AppNotificationsPage(model: model))),
      Page(name: "Appearance", view: AnyView(AppAppearancePage(model: model))),
      Page(
        name: "Project General",
        view: AnyView(ProjectGeneralPage(model: model, project: project)),
      ),
      Page(
        name: "Project Worktrees",
        view: AnyView(ProjectWorktreesPage(model: model, project: project)),
      ),
      Page(
        name: "Project Hooks, Create",
        view: AnyView(ProjectHooksPage(model: model, project: project, section: .hooksCreate)),
      ),
      Page(
        name: "Project Hooks, Create, a repository file asking for trust",
        view: AnyView(
          ProjectHooksPage(model: model, project: project.askingForTrust(), section: .hooksCreate)
        ),
      ),
      Page(
        name: "Project Hooks, Delete",
        view: AnyView(ProjectHooksPage(model: model, project: project, section: .hooksDelete)),
      ),
      Page(
        name: "Project Hooks, Environment",
        view: AnyView(
          ProjectHooksPage(model: model, project: project, section: .hooksEnvironment)
        ),
      ),
      Page(
        name: "Project Terminal",
        view: AnyView(ProjectTerminalPage(model: model, project: project)),
      ),
      Page(
        name: "Project Agents",
        view: AnyView(ProjectAgentsPage(model: model, project: project)),
      ),
      Page(
        name: "Project Integrations",
        view: AnyView(ProjectIntegrationsPage(model: model, project: project)),
      ),
    ]
  }

  @Test func noSettingsPageIsTallerThanTheColumnItOpensIn() {
    for page in Self.pages(of: ModelHarness()) {
      let needed = OffscreenHost.read(
        page.view,
        atWidth: UIMetrics.settingsPageSize.width,
        windowSize: CGSize(width: 10, height: 10),
        sizingOptions: [.minSize, .intrinsicContentSize],
      ) { $0.intrinsicContentSize.height }
      #expect(
        needed <= UIMetrics.settingsPageSize.height,
        "\(page.name) needs \(needed)pt, the column is \(UIMetrics.settingsPageSize.height)pt",
      )
    }
  }
}

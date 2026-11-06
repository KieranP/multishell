/// Where the settings window is: whose settings, and which section of them.
public struct SettingsLocation: Hashable, Sendable {
  /// Where Multishell > Settings opens.
  static let start = Self(scope: .allProjects, section: .general)

  public let scope: SettingsScope
  public let section: SettingsSection

  /// Whether the sidebar row of `page` is the one selected: a whole page's,
  /// never a split page's own row, whose parts take the selection.
  public func selects(_ page: SettingsPage) -> Bool {
    !section.isPart && section.page == page
  }

  /// The section `offset` rows down the sidebar's `pages`, their parts
  /// counted, held to the first and last, onto the list where it hides this one.
  func stepped(by offset: Int, among pages: [SettingsPage]) -> Self {
    let sections = pages.flatMap { $0.sections(in: scope) }
    guard let last = sections.indices.last else { return self }
    let start = sections.firstIndex(of: section) ?? (offset > 0 ? -1 : last + 1)
    let next = min(max(start + offset, 0), last)
    return Self(scope: scope, section: sections[next])
  }

  /// The same page in another scope where it has one, so a project's
  /// Worktrees turns into All Projects' Worktrees; General where it has not.
  func moved(to scope: SettingsScope) -> Self {
    let sections = section.page.sections(in: scope)
    let kept = sections.contains(section) ? section : sections.first ?? .general
    return Self(scope: scope, section: kept)
  }
}

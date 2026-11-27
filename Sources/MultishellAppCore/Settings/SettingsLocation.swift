import MultishellCore

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

  /// Whether the sidebar lists a split page's parts: only while one of them is
  /// open, so the pages around it stay one row each.
  public func showsParts(of page: SettingsPage) -> Bool {
    section.page == page
  }

  /// The section `offset` rows down the sidebar's `pages`, held to the first and
  /// last, onto the list where it hides this one. A closed split page's row opens its first part.
  func stepped(by offset: Int, among pages: [SettingsPage]) -> Self {
    let sections = pages.flatMap { page in
      let sections = page.sections(in: scope)
      return showsParts(of: page) ? sections : Array(sections.prefix(1))
    }
    guard let last = sections.indices.last else { return self }
    let start = sections.firstIndex(of: section) ?? (offset > 0 ? -1 : last + 1)
    let next = (start + offset).clamped(to: 0...last)
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

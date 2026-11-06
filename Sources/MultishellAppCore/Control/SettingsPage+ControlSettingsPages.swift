import MultishellCore

extension SettingsPage {
  private var wholePageWord: ControlSettingsPage? {
    ControlSettingsPage.allCases.first { word in
      let section = SettingsSection(word)
      return section.page == self && !section.isPart
    }
  }

  /// The words `--page` takes for the page in `scope`: one per section, and a
  /// split page's own word, which opens its first part, ahead of its parts'.
  func controlSettingsPages(in scope: SettingsScope) -> [ControlSettingsPage] {
    let sections = sections(in: scope)
    let words = sections.map(ControlSettingsPage.init)
    guard sections.contains(where: \.isPart), let whole = wholePageWord else { return words }
    return [whole] + words
  }
}

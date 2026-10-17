/// An entry in a theme's `ui` section, written in the file as its raw value:
/// a part of the window, or a set of colours several parts share.
public enum InterfaceSection: String, CaseIterable, Sendable {
  case agentsCard = "agents_card"
  case agentsColumn = "agents_column"
  case agentsPanel = "agents_panel"
  case debugInfo = "debug_info"
  /// What the detail area shows with no tab in it: a placeholder, or a
  /// worktree being created or removed.
  case detail
  case filesPanel = "files_panel"
  case fileTab = "file_tab"
  case findBar = "find_bar"
  case git
  /// The worktree's header and the board's, Debug Info's and the Files panel's.
  case header
  case projectsPanel = "projects_panel"
  case states
  case tabBar = "tab_bar"
  case terminalTab = "terminal_tab"

  /// The colours the section takes; a key it does not list is never read.
  var colorKeys: [InterfaceColorKey] {
    let text: [InterfaceColorKey] = [.text, .textSecondary, .textTertiary]
    return switch self {
    case .agentsCard: [.background] + text + [.border, .fill, .highlight]

    case .agentsColumn: [.background, .text, .textTertiary, .border]

    case .agentsPanel: [.background, .textTertiary, .border]

    case .debugInfo:
      [.background] + text + [.border, .fill, .blockBackground]
        + [.seriesApp, .seriesTerminals, .seriesChildren, .hitch, .stall]

    case .detail: [.background] + text + [.blockBackground]

    case .fileTab: [.background] + text + [.border, .fill, .selectionBackground]

    case .filesPanel: [.background] + text + [.border, .fill, .selectionBackground]

    case .findBar:
      [.background, .text, .textSecondary, .border, .fill]
        + [.fieldBackground, .fieldText, .fieldTextSecondary, .fieldBorder]

    case .git: [.added, .removed, .changed, .merged]

    case .header:
      [.background] + text + [.border, .fill, .selectionBackground, .accent, .highlight, .knob]

    case .projectsPanel: [.background] + text + [.border, .fill, .selection, .selectionBackground]

    case .states: [.working, .waiting, .done, .failed]

    case .tabBar: [.background] + text + [.border, .selection]

    case .terminalTab: [.background] + text + [.border, .divider, .selection]
    }
  }
}

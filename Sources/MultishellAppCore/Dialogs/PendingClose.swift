import Foundation
import MultishellCore

/// A close waiting on its dialog: a pane or tab whose agent reported Working, or a
/// file tab with a review comment being written. Cmd+W there is often a mistake.
public enum PendingClose: Identifiable, Equatable, Sendable {
  case fileTab(FileTab.ID)
  case pane(TerminalSession.ID)
  case tab(TerminalTab.ID)

  public var id: String {
    switch self {
    case .fileTab(let id): "file-tab-\(id.uuidString)"
    case .pane(let id): "pane-\(id.uuidString)"
    case .tab(let id): "tab-\(id.uuidString)"
    }
  }

  public var title: String {
    switch self {
    case .pane: t("close.pane-title")
    case .fileTab, .tab: t("close.tab-title")
    }
  }

  public var message: String {
    switch self {
    case .fileTab: t("close.review-draft-message")
    case .pane, .tab: t("dialog.agent-still-working")
    }
  }

  public var buttonLabel: String {
    switch self {
    case .pane: t("close.pane-button")
    case .fileTab, .tab: t("close.tab-button")
    }
  }

  /// The shells this close would end: the one pane, or every pane of the
  /// tab. What decides whether the question is asked at all.
  func sessionIDs(in tab: TerminalTab) -> [TerminalSession.ID] {
    switch self {
    case .fileTab: []
    case .pane(let id): [id]
    case .tab: tab.sessionIDs
    }
  }
}

import Foundation

/// One request from the command line, answered on its own connection; a
/// project or worktree named by its `ControlID`. Cases are only ever added.
public enum ControlRequest: Codable, Equatable, Sendable {
  case addProject(path: String)
  case closePane(id: UUID, force: Bool)
  case closeTab(id: UUID, force: Bool)
  /// The newest `last` git runs, each on its own.
  case debugGitRuns(last: Int)
  case debugMemory
  /// The banners posted and the Dock badge, as the app logged posting them.
  case debugNotifications
  case debugSamples(last: Int)
  /// The newest `last` samples summed up: each reading's least, mean and most.
  case debugSummary(last: Int)
  case describePane(id: UUID)
  /// The tab and its panes as laid out, each on-screen one's frame in points.
  case describeTab(id: UUID)
  /// The worktree with the git status its row shows and any stage under way.
  case describeWorktree(id: String)
  /// The alert, dialog, sheet or field on top, as its Cancel would.
  case dismissPresentation
  case filterSidebar(text: String)
  case findInPane(id: UUID, action: PaneFindAction)
  case hideView(ControlView)
  case info
  /// The Agents board's columns and cards, as it would draw them now.
  case listBoard
  /// Every item of the menu bar, by its titles from the bar down.
  case listMenuItems
  case listProjects
  /// The sidebar's rows as drawn: filtered, ordered, collapsed.
  case listSidebar
  /// `nil` lists every worktree's.
  case listTabs(worktree: String?)
  case listWorktrees(project: String?)
  /// A name put into the next debug sample and the signpost log.
  case markDebugSample(name: String)
  case moveTab(id: UUID, placement: TerminalTab.Placement, anchor: UUID)
  case newTab(NewTabOrder)
  case newWorktree(NewWorktreeOrder)
  /// Text put in as a paste, bracketed where the program asked.
  case pasteIntoPane(id: UUID, text: String)
  /// A menu item by its titles, as a click on it.
  case performMenuItem(path: [String])
  case pressKeys(id: UUID, keys: [ControlKey])
  case quit(force: Bool)
  /// `nil` reads every key.
  case readGlobalSettings(key: String?)
  case readPane(id: UUID, includingScrollback: Bool)
  case readProjectSettings(project: String, key: String?)
  case removeProject(id: String, force: Bool)
  case removeWorktree(WorktreeRemovalOrder)
  /// `nil` hands the title back to the shell.
  case renameTab(id: UUID, title: String?)
  /// `nil` hands the name back to the branch.
  case renameWorktree(id: String, name: String?)
  /// A state for the pane its session names, as a hook reporting it would.
  case reportPaneState(SessionStateReport)
  case resizeWindow(width: Double, height: Double)
  /// The main window as drawn, or one pane, as a PNG screenshot.
  case screenshot(pane: UUID?)
  case selectPane(id: UUID)
  case selectTab(id: UUID)
  case selectWorktree(id: String)
  case setDebugInfo(shown: Bool)
  case setDebugTools(enabled: Bool)
  case setFullScreen(on: Bool)
  /// `project` names the one project settings shows.
  case showView(ControlView, project: String?)
  case splitPane(axis: SplitAxis, tab: UUID?)
  case typeIntoPane(id: UUID, text: String, pressingReturn: Bool)
  case writeGlobalSetting(key: String, value: String)
  case writeProjectSetting(project: String, key: String, value: String)

  /// The wire's one object a line: the version beside the request, which
  /// a report never holds, so neither parses as the other.
  private struct Envelope: Codable {
    enum CodingKeys: String, CodingKey {
      case request
      case version = "v"
    }

    let version: Int
    let request: ControlRequest
  }

  public static let protocolVersion = 1

  /// `nil` for anything else: a report, a stray line, or a request from a
  /// newer helper, whose cases may mean something else by now.
  public static func parse(_ line: String) -> Self? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
      let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(trimmed.utf8)),
      envelope.version <= protocolVersion
    else { return nil }
    return envelope.request
  }

  public func encodedLine() throws -> String {
    try JSONEncoder.socketLine(Envelope(version: Self.protocolVersion, request: self))
  }
}

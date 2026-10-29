import MultishellCore

extension Helper {
  static let usage = """
    usage: multishell <command> [arguments]

    Drive the Multishell app this helper came with: a debug build's helper
    drives the debug app, a release build's the release app, whichever app's
    tab it runs in.

    PROJECT_ID and WORKTREE_ID are the ids `projects list` and `worktrees
    list` print, such as p-3f9a2c1d and w-8b1e04aa; TAB_ID and PANE_ID the
    ones `tabs list` prints. Of the commands that drive the app, only
    `projects add`, `debug screenshot` and `debug services stand-in` take a
    path from where they run; `tabs open-file` and `files` take one inside
    the worktree. Whatever a command prints is JSON; `panes read` and
    `debug log` take --plain for text.

      open                       Start the app, or bring it forward
      quit [--force]             Quit the app without its confirmation
      info                       Print the app's pid, files, windows and what
                                 is up on screen, as JSON
      config global list|get|set           Read or change a setting
      config project PROJECT_ID list|get|set
      projects list|add|remove|expand|collapse|move|refresh|fetch
                                 The sidebar's projects
      worktrees list|add|show|rename|remove|select|auto-rename|clear-status|
                resize-groups
      tabs list|open|open-file|show|select|close|move|rename|resize|
           clear-status|step|find
      panes split|select|close|type|paste|key|show|read|wait|find|clear-status
      files list|filter|expand|collapse
                                 The Files panel's list
      board list                 The Agents board's columns and cards
      sidebar list               The sidebar's rows as drawn
      ui show|hide|filter|dismiss|menu|switcher
                                 The board, settings, filter, dialogs, menus,
                                 the quick switcher
      window size|full-screen|sidebar-width|panel-width
                                 Size the main window and its panels
      debug tools on|off         Turn Debug Tools on or off
      debug info show|hide       Show or hide Debug Info
      debug samples|memory|git|notifications
                                 Print Debug Info's readings, or the banners
      debug mark|report|screenshot|log|services
                                 Mark a sample, report a state, draw, read logs,
                                 stand in for gh and circleci

    For hooks and the shell integration, which report to the app:
      state, command-started, command-finished, relay, agent-hook

    Setting up an agent's hooks:
      install-agent-hooks, remove-agent-hooks

      help [COMMAND]             Show a command's arguments
      --version

    """

  /// Each command word to the text that covers it.
  private static let usageByTopic: [String: String] = {
    let topics: [([String], String)] = [
      (Array(helpCommands), usage),
      (["version", "--version"], versionUsage),
      ([stateName], stateUsage),
      ([commandStartedName, commandFinishedName, relayName], shellReportUsage),
      (
        [AgentHookCatalogue.subcommand, installHooksName, removeHooksName],
        agentHookUsage,
      ),
    ]
    let controlTopics = ControlCommand.allCases.map { ([$0.rawValue], usage(of: $0)) }
    return Dictionary(
      keepingFirst: (topics + controlTopics).flatMap { words, text in words.map { ($0, text) } }
    )
  }()

  /// One command's arguments, or `nil` for a word that is not a command.
  static func usage(of topic: String) -> String? {
    usageByTopic[topic]
  }

  private static func usage(of command: ControlCommand) -> String {
    switch command {
    case .info, .open, .quit: appUsage
    case .board: boardUsage
    case .config: configUsage
    case .debug: debugUsage
    case .files: filesUsage
    case .panes: paneUsage
    case .projects: projectUsage
    case .sidebar: sidebarUsage
    case .tabs: tabUsage
    case .userInterface: uiUsage
    case .window: windowUsage
    case .worktrees: worktreeUsage
    }
  }
}

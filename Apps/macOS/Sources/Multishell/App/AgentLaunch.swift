import Foundation
import MultishellCore
import MultishellProcess

/// The command line an agent tab runs, built at the moment the shell starts.
///
/// Through the user's interactive login shell, for two reasons: the agent
/// is found on the PATH a terminal has rather than the Finder's, and when
/// the agent quits the tab would close with its scrollback, so a login shell
/// takes over instead. The shell that runs `-c` is the one hooks use
/// (`ShellCommand.shell`); `exec` is the fragment that starts the shell that
/// follows, from `ShellLaunch.execCommandLine`, integration included.
enum AgentLaunch {
  static func command(
    agent arguments: [String],
    shell: (executable: URL, arguments: [String]),
    exec: String
  ) -> [String] {
    line(ShellQuoting.commandLine(arguments), shell: shell, exec: exec)
  }

  /// The custom entry is a shell line as the user typed it.
  static func command(
    customLine: String,
    shell: (executable: URL, arguments: [String]),
    exec: String
  ) -> [String]? {
    let trimmed = customLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return line(trimmed, shell: shell, exec: exec)
  }

  /// `nil` when a relaunch has nothing to resume with; the tab is then a
  /// plain shell that keeps the agent's title.
  static func arguments(for agent: AgentDescriptor, resume: Bool) -> [String]? {
    if resume {
      return agent.resumeArguments.map { [agent.executable] + $0 }
    }
    return [agent.executable] + agent.launchArguments
  }

  private static func line(
    _ commandLine: String, shell: (executable: URL, arguments: [String]), exec: String
  ) -> [String] {
    [shell.executable.path] + shell.arguments + ["\(commandLine); \(exec)"]
  }
}

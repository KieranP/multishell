import Foundation
import MultishellCore

/// The command line an agent tab runs, built as the shell starts. Through the
/// login shell, for its PATH and so a shell takes over when the agent quits.
public enum AgentLaunch {
  public static func command(
    agent arguments: [String],
    shell: (executable: URL, arguments: [String]),
    exec: String
  ) -> [String] {
    line(ShellQuoting.commandLine(arguments), shell: shell, exec: exec)
  }

  /// The custom entry is a shell line as the user typed it.
  public static func command(
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
  public static func arguments(for agent: AgentDescriptor, resume: Bool) -> [String]? {
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

import Foundation

/// Who ran us: the nearest ancestor that is not a shell, so a hook's helper
/// reports the agent rather than the `sh -c` layers between.
public enum ProcessAncestry {
  /// Shells an agent might run a hook through. `login` is what a terminal
  /// puts under itself.
  static let shells: Set<String> = [
    "sh", "bash", "zsh", "dash", "fish", "ksh", "mksh", "tcsh", "csh", "login",
  ]

  /// `stoppingAt` is the app's own pid: from a prompt in one of its tabs
  /// nothing between the shell and it is a program, so the shell is named.
  public static func reportingProcess(
    startingAt pid: Int32 = getppid(), stoppingAt boundary: Int32? = nil
  ) -> Int32 {
    var current = pid
    for _ in 0..<16 {
      guard let name = KernelProcessTable.name(of: current), shells.contains(name),
        let parent = KernelProcessTable.parent(of: current), parent > 1, parent != boundary
      else { return current }
      current = parent
    }
    return current
  }

  /// The process's children whose command line holds `marker`, which is how
  /// an agent's own shells are told from its MCP servers.
  public static func children(of pid: Int32, whoseArgumentsContain marker: String) -> [Int32] {
    KernelProcessTable.children(of: pid).filter {
      KernelProcessTable.commandLine(of: $0)?.contains(marker) == true
    }
  }
}

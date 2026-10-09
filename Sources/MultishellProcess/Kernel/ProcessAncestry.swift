import Foundation

/// Who ran us: the nearest ancestor that is not a shell, so a hook's helper
/// reports the agent rather than the `sh -c` layers between.
public enum ProcessAncestry {
  /// Shells an agent might run a hook through. `login` is what a terminal
  /// puts under itself.
  private static let shells: Set<String> = ShellInvocation.interactiveLoginShells
    .union(ShellInvocation.loginFlagRefusers).union(["login"])

  /// `stoppingAt` is the app's own pid: from a prompt in one of its tabs
  /// nothing between the shell and it is a program, so the shell is named.
  public static func reportingPID(
    startingAt pid: Int32 = getppid(),
    stoppingAt boundary: Int32? = nil,
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
}

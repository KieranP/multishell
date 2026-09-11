import Foundation

/// Writes the shell-integration files, rewritten each launch so a moved
/// bundle's helper path stays current; see docs/design/terminals.md.
public enum ShellIntegration {
  public static func refresh(
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile,
    helper: String = AgentHooks.helperReference
  ) throws {
    try FileManager.default.createDirectory(at: zshDirectory, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: helper) {
      try Data(contents.utf8).write(
        to: zshDirectory.appendingPathComponent(name, isDirectory: false), options: .atomic)
    }

    try FileManager.default.createDirectory(
      at: bashInit.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(ShellStateHooks.bashInitFile(helper: helper).utf8).write(
      to: bashInit, options: .atomic)
  }
}

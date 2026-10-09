import Foundation

/// Writes the shell-integration files, rewritten each launch so a moved
/// bundle's helper path stays current; see Docs/design/terminals.md.
public enum ShellIntegration {
  public static func refresh(
    zshDirectory: URL = Paths.zshIntegrationDirectory,
    bashInit: URL = Paths.bashInitFile,
    helper: String = AgentHookCatalogue.helperReference,
  ) throws {
    for (name, contents) in ShellIntegrationScripts.forZsh(helper: helper) {
      try Data(contents.utf8).writeAtomicallyCreatingDirectory(
        to: zshDirectory.appendingPathComponent(name, isDirectory: false)
      )
    }

    try Data(ShellIntegrationScripts.forBash(helper: helper).utf8).writeAtomicallyCreatingDirectory(
      to: bashInit
    )
  }
}

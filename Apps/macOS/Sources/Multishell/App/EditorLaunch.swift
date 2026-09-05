import Foundation
import MultishellCore

/// What Open in Editor does for the editor in force, decided apart from the
/// view and the model so it can be tested.
enum EditorLaunch {
  enum Action: Equatable {
    /// Hand the directory to the application.
    case openApplication(URL)
    /// Run the editor's command line shim through the login shell, in the
    /// background: the application it starts is what the user sees.
    case runInBackground(String)
    /// A terminal editor, or the custom command: a new tab in the worktree
    /// running it, with a shell taking over when it exits.
    case openTab(title: String, command: [String])
  }

  /// `nil` when the editor is in the catalogue but not installed.
  static func action(
    editorID: String,
    found: EditorDetection.Found?,
    customTemplate: String,
    directory: URL,
    shell: (executable: URL, arguments: [String]),
    exec: String
  ) -> Action? {
    if editorID == EditorCatalogue.customID {
      guard let line = EditorCatalogue.customCommandLine(customTemplate, path: directory),
        let command = AgentLaunch.command(customLine: line, shell: shell, exec: exec)
      else { return nil }
      return .openTab(title: title(of: line), command: command)
    }
    guard let editor = EditorCatalogue.editor(editorID) else { return nil }
    switch editor.kind {
    case .application:
      if let application = found?.application { return .openApplication(application) }
      guard let command = found?.command else { return nil }
      return .runInBackground(ShellQuoting.commandLine([command.path, directory.path]))
    case .terminal:
      guard let command = found?.command else { return nil }
      return .openTab(
        title: editor.name,
        command: AgentLaunch.command(agent: [command.path, "."], shell: shell, exec: exec))
    }
  }

  /// The command's first word, for the tab.
  private static func title(of line: String) -> String {
    let first = line.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "Editor"
    return URL(fileURLWithPath: first).lastPathComponent
  }
}

import Foundation
import MultishellCore
import MultishellProcess

/// What Open in Editor does for the editor in force, decided apart from the
/// view and the model so it can be tested.
enum EditorLaunch {
  enum Action: Equatable {
    case openApplication(URL)
    /// A terminal editor, or the custom command: a new tab in the worktree
    /// running it, with a shell taking over when it exits.
    case openTab(title: String, command: [String])
    /// Run the editor's command line shim through the login shell, in the
    /// background: the application it starts is what the user sees.
    case runInBackground(String)
  }

  /// `nil` when the editor is in the catalogue but not installed.
  static func action(
    editorID: String,
    found: EditorDetection.Found?,
    customTemplate: String,
    directory: URL,
    shell: ShellInvocation,
    handOver: String,
  ) -> Action? {
    if editorID == EditorCatalogue.customID {
      guard let line = EditorCatalogue.customCommandLine(customTemplate, path: directory),
        let command = TabCommand.running(customLine: line, shell: shell, handOver: handOver)
      else { return nil }
      return .openTab(title: title(of: line.text), command: command)
    }
    guard let editor = EditorCatalogue.editor(editorID) else { return nil }
    switch editor.kind {
    case .application:
      if let application = found?.application { return .openApplication(application) }
      guard let executable = found?.executable else { return nil }
      return .runInBackground(
        AnyShellQuoting.commandLine([executable.path, directory.path])
      )

    case .terminal:
      guard let executable = found?.executable else { return nil }
      return .openTab(
        title: editor.name,
        command: TabCommand.running([executable.path, "."], shell: shell, handOver: handOver),
      )
    }
  }

  /// The command's first word, for the tab.
  private static func title(of line: String) -> String {
    let first = line.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? t("tab.editor")
    return first.executableName
  }
}

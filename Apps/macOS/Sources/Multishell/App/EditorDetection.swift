import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue editors this Mac has, and how the dropdown lists them.
///
/// Editors are mostly applications, not PATH binaries, so each is looked up
/// by bundle identifier through `applicationLookup` (`NSWorkspace` in the
/// app, a table in tests) and, failing that, by its command line shim on the
/// login shell's PATH. Terminal editors are PATH binaries only.
struct EditorDetection: Equatable {
  struct Found: Equatable {
    let application: URL?
    let command: URL?
  }

  struct Option: Identifiable, Equatable {
    let id: String
    let label: String
    let isInstalled: Bool
  }

  let found: [String: Found]

  static let empty = EditorDetection(found: [:])

  init(found: [String: Found]) {
    self.found = found
  }

  init(path: String?, applicationLookup: (String) -> URL?) {
    var found: [String: Found] = [:]
    for editor in EditorCatalogue.editors {
      let application = editor.bundleIdentifier.flatMap(applicationLookup)
      let command = editor.command.flatMap { ExecutableLookup.find($0, path: path) }
      if application != nil || command != nil {
        found[editor.id] = Found(application: application, command: command)
      }
    }
    self.found = found
  }

  func isInstalled(_ id: String) -> Bool {
    id == EditorCatalogue.customID || found[id] != nil
  }

  /// None, the installed editors in catalogue order, the selected one if it
  /// is not installed, then Custom.
  func options(selected: String?) -> [Option] {
    var options = [Option(id: EditorCatalogue.noneID, label: "None", isInstalled: true)]
    for editor in EditorCatalogue.editors {
      if found[editor.id] != nil {
        options.append(Option(id: editor.id, label: editor.name, isInstalled: true))
      } else if editor.id == selected {
        options.append(
          Option(id: editor.id, label: "\(editor.name) (not installed)", isInstalled: false))
      }
    }
    if let selected, selected != EditorCatalogue.noneID, selected != EditorCatalogue.customID,
      EditorCatalogue.editor(selected) == nil
    {
      options.append(Option(id: selected, label: "\(selected) (not installed)", isInstalled: false))
    }
    options.append(
      Option(id: EditorCatalogue.customID, label: "Custom command…", isInstalled: true))
    return options
  }
}

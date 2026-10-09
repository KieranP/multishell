import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue editors this machine has. Mostly applications, so each is
/// looked up by platform identifier and then by its shim on the PATH.
public struct EditorDetection: Equatable, Sendable {
  struct Found: Equatable, Sendable {
    let application: URL?
    let executable: URL?
  }

  static let empty = Self(found: [:])

  let found: [String: Found]

  init(found: [String: Found]) {
    self.found = found
  }

  init(searchPath: String?, applicationLookup: (String) -> URL?) {
    var found: [String: Found] = [:]
    for editor in EditorCatalogue.editors {
      let application = editor.bundleIdentifier.flatMap(applicationLookup)
      let executable = editor.executable.flatMap { executable in
        ExecutableLookup.find(executable, searchPath: searchPath)
      }
      if application != nil || executable != nil {
        found[editor.id] = Found(application: application, executable: executable)
      }
    }
    self.found = found
  }

  public func options(selected: String?) -> [DetectionOption] {
    DetectionOption.catalogueOptions(
      EditorCatalogue.editors.map { ($0.id, $0.name) },
      isInstalled: { found[$0] != nil },
      selected: selected,
      noneID: EditorCatalogue.noneID,
      customID: EditorCatalogue.customID,
    )
  }
}

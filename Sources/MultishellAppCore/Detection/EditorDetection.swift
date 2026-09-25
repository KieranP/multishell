import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue editors this machine has. Mostly applications, so each is
/// looked up by platform identifier and then by its shim on the PATH.
public struct EditorDetection: Equatable, Sendable {
  struct Found: Equatable, Sendable {
    let application: URL?
    let command: URL?

    init(application: URL?, command: URL?) {
      self.application = application
      self.command = command
    }
  }

  let found: [String: Found]

  static let empty = EditorDetection(found: [:])

  init(found: [String: Found]) {
    self.found = found
  }

  init(searchPath: String?, applicationLookup: (String) -> URL?) {
    var found: [String: Found] = [:]
    for editor in EditorCatalogue.editors {
      let application = editor.bundleIdentifier.flatMap(applicationLookup)
      let command = editor.command.flatMap { ExecutableLookup.find($0, searchPath: searchPath) }
      if application != nil || command != nil {
        found[editor.id] = Found(application: application, command: command)
      }
    }
    self.found = found
  }

  public func options(selected: String?) -> [DetectionOption] {
    DetectionOption.catalogueOptions(
      EditorCatalogue.editors.map { ($0.id, $0.name) },
      installed: { found[$0] != nil },
      selected: selected,
      noneID: EditorCatalogue.noneID,
      customID: EditorCatalogue.customID)
  }
}

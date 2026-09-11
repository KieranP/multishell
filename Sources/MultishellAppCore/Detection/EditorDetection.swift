import Foundation
import MultishellCore
import MultishellProcess

/// Which catalogue editors this machine has. Mostly applications, so each is
/// looked up by platform identifier and then by its shim on the PATH.
public struct EditorDetection: Equatable, Sendable {
  public struct Found: Equatable, Sendable {
    public let application: URL?
    public let command: URL?

    public init(application: URL?, command: URL?) {
      self.application = application
      self.command = command
    }
  }

  public let found: [String: Found]

  public static let empty = EditorDetection(found: [:])

  public init(found: [String: Found]) {
    self.found = found
  }

  public init(path: String?, applicationLookup: (String) -> URL?) {
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

  public func isInstalled(_ id: String) -> Bool {
    id == EditorCatalogue.customID || found[id] != nil
  }

  public func options(selected: String?) -> [DetectionOption] {
    DetectionOption.catalogue(
      EditorCatalogue.editors.map { ($0.id, $0.name) },
      installed: { found[$0] != nil },
      selected: selected,
      noneID: EditorCatalogue.noneID,
      customID: EditorCatalogue.customID)
  }
}

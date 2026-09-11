import Foundation
import MultishellCore

/// One row of a settings dropdown that lists what a machine has.
///
/// A picker whose selection is not in its list shows blank, so a stored id
/// that is no longer installed is listed, marked as such, rather than
/// dropped; `isInstalled` is false for that row only.
public struct DetectionOption: Identifiable, Equatable, Sendable {
  public let id: String
  public let label: String
  public let isInstalled: Bool

  public init(id: String, label: String, isInstalled: Bool) {
    self.id = id
    self.label = label
    self.isInstalled = isInstalled
  }
}

extension DetectionOption {
  /// The shape the agent and editor dropdowns share: None, the installed
  /// entries in catalogue order, the selected one if it is not installed,
  /// an id the catalogue does not know at all (a newer build's), then
  /// Custom.
  static func catalogue(
    _ entries: [(id: String, name: String)],
    installed: (String) -> Bool,
    selected: String?,
    noneID: String,
    customID: String
  ) -> [DetectionOption] {
    var options = [DetectionOption(id: noneID, label: t("option.none"), isInstalled: true)]
    for entry in entries {
      if installed(entry.id) {
        options.append(DetectionOption(id: entry.id, label: entry.name, isInstalled: true))
      } else if entry.id == selected {
        options.append(
          DetectionOption(
            id: entry.id, label: t("option.not-installed", entry.name), isInstalled: false))
      }
    }
    if let selected, selected != noneID, selected != customID,
      !entries.contains(where: { $0.id == selected })
    {
      options.append(
        DetectionOption(
          id: selected, label: t("option.not-installed", selected), isInstalled: false))
    }
    options.append(
      DetectionOption(id: customID, label: t("option.custom-command-item"), isInstalled: true))
    return options
  }
}

import Foundation
import MultishellCore

/// One row of a settings dropdown listing what a machine has. A picker whose
/// selection is missing shows blank, so an uninstalled id is listed, marked.
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
  /// The shape the agent and editor dropdowns share: None, what is installed,
  /// the selected one if it is not, an unknown id, then Custom.
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

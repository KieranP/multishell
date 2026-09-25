import MultishellCore

/// One row of a settings dropdown listing what a machine has. A picker whose
/// selection is missing shows blank, so an uninstalled id is listed, marked.
public struct DetectionOption: Identifiable, Equatable, Sendable {
  /// A row that is not an option: the picker draws a divider.
  public static let dividerID = "\u{0}divider"

  public let id: String
  public let label: String
}

extension DetectionOption {
  /// The shape the agent and editor dropdowns share: None, what is installed,
  /// the selected one if it is not, an unknown id, then Custom.
  static func catalogueOptions(
    _ entries: [(id: String, name: String)],
    installed: (String) -> Bool,
    selected: String?,
    noneID: String,
    customID: String
  ) -> [DetectionOption] {
    var options = [DetectionOption(id: noneID, label: t("option.none"))]
    for entry in entries {
      if installed(entry.id) {
        options.append(DetectionOption(id: entry.id, label: entry.name))
      } else if entry.id == selected {
        options.append(.notInstalled(entry.id, name: entry.name))
      }
    }
    if let selected, selected != noneID, selected != customID,
      !entries.contains(where: { $0.id == selected })
    {
      options.append(.notInstalled(selected, name: selected))
    }
    options.append(DetectionOption(id: customID, label: t("option.custom-command-item")))
    return options
  }

  static func notInstalled(_ id: String, name: String) -> DetectionOption {
    DetectionOption(id: id, label: t("option.not-installed", name))
  }
}

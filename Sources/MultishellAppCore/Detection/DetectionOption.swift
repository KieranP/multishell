import MultishellCore

/// One row of a settings dropdown listing what a machine has. A picker whose
/// selection is missing shows blank, so an uninstalled id is listed, marked.
public struct DetectionOption: Identifiable, Equatable, Sendable {
  /// A row that is not an option: the picker draws a divider.
  public static let dividerID = "\u{0}divider"

  public let id: String
  public let label: String

  /// The shape the agent and editor dropdowns share: None, what is installed,
  /// the selected one if it is not, an unknown id, then Custom.
  static func catalogueOptions(
    _ entries: [(id: String, name: String)],
    isInstalled: (String) -> Bool,
    selected: String?,
    noneID: String,
    customID: String,
  ) -> [Self] {
    [Self(id: noneID, label: t("option.none"))]
      + installedOrSelectedOptions(
        entries,
        isInstalled: isInstalled,
        selected: selected,
        reserved: [noneID, customID],
      )
      + [Self(id: customID, label: t("option.custom-command-item"))]
  }

  /// What is installed, then the selected one marked where it is not, or
  /// where no entry has its id and it is none of `reserved`.
  static func installedOrSelectedOptions(
    _ entries: [(id: String, name: String)],
    isInstalled: (String) -> Bool,
    selected: String?,
    reserved: Set<String>,
  ) -> [Self] {
    var options: [Self] = []
    for entry in entries {
      if isInstalled(entry.id) {
        options.append(Self(id: entry.id, label: entry.name))
      } else if entry.id == selected {
        options.append(.notInstalled(entry.id, name: entry.name))
      }
    }
    if let selected, !reserved.contains(selected), !entries.contains(where: { $0.id == selected }) {
      options.append(.notInstalled(selected, name: selected))
    }
    return options
  }

  static func notInstalled(_ id: String, name: String) -> Self {
    Self(id: id, label: t("option.not-installed", name))
  }
}

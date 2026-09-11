import Foundation
import MultishellCore

/// The font families the picker offers: system monospace, the monospaced
/// families, then the rest, some programming fonts not being fixed-pitch.
public struct FontDetection: Equatable, Sendable {
  /// The id of the "System monospace" entry, the `nil` font name.
  public static let systemID = ""
  /// A row in the options that is not a font: the picker draws a divider.
  public static let dividerID = "\u{0}divider"

  public let monospaced: [String]
  public let others: [String]

  public static let empty = FontDetection(monospaced: [], others: [])

  public init(monospaced: [String], others: [String]) {
    self.monospaced = monospaced.sorted {
      $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
    self.others = others.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  public func isInstalled(_ family: String) -> Bool {
    family == Self.systemID || monospaced.contains(family) || others.contains(family)
  }

  public func options(selected: String?) -> [DetectionOption] {
    var options = [
      DetectionOption(
        id: Self.systemID, label: t("option.system-monospace"), isInstalled: true)
    ]
    options += monospaced.map { DetectionOption(id: $0, label: $0, isInstalled: true) }
    if let selected, !selected.isEmpty, !isInstalled(selected) {
      options.append(
        DetectionOption(
          id: selected, label: t("option.not-installed", selected), isInstalled: false))
    }
    if !others.isEmpty {
      options.append(DetectionOption(id: Self.dividerID, label: "", isInstalled: true))
      options += others.map { DetectionOption(id: $0, label: $0, isInstalled: true) }
    }
    return options
  }
}

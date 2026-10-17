import Foundation
import MultishellCore

/// The font families a picker offers: the system's, then the families that
/// suit it first, then the rest, some programming fonts not being fixed-pitch.
public struct FontDetection: Equatable, Sendable {
  /// The id of the system font's entry, the `nil` font name.
  static let systemID = ""

  let monospaced: [String]
  let otherFamilies: [String]

  public init(monospaced: [String], otherFamilies: [String]) {
    self.monospaced = monospaced.sorted { lhs, rhs in
      lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
    self.otherFamilies = otherFamilies.sorted { lhs, rhs in
      lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  private func isInstalled(_ family: String) -> Bool {
    family == Self.systemID || monospaced.contains(family) || otherFamilies.contains(family)
  }

  /// A code font's: system monospace, then the monospaced families.
  public func options(selected: String?) -> [DetectionOption] {
    options(
      system: t("option.system-monospace"),
      first: monospaced,
      then: otherFamilies,
      selected: selected,
    )
  }

  /// The UI font's: the proportional system font, then the proportional
  /// families.
  public func uiFontOptions(selected: String?) -> [DetectionOption] {
    options(
      system: t("option.system-font"),
      first: otherFamilies,
      then: monospaced,
      selected: selected,
    )
  }

  private func options(
    system: String,
    first: [String],
    then rest: [String],
    selected: String?,
  ) -> [DetectionOption] {
    var options = [DetectionOption(id: Self.systemID, label: system)]
    options += first.map { DetectionOption(id: $0, label: $0) }
    if let selected, !selected.isEmpty, !isInstalled(selected) {
      options.append(.notInstalled(selected, name: selected))
    }
    if !rest.isEmpty {
      options.append(DetectionOption(id: DetectionOption.dividerID, label: ""))
      options += rest.map { DetectionOption(id: $0, label: $0) }
    }
    return options
  }
}

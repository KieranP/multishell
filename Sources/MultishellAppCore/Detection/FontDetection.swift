import Foundation
import MultishellCore

/// The font families the picker offers: system monospace, the monospaced
/// families, then the rest, some programming fonts not being fixed-pitch.
public struct FontDetection: Equatable, Sendable {
  /// The id of the "System monospace" entry, the `nil` font name.
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

  func isInstalled(_ family: String) -> Bool {
    family == Self.systemID || monospaced.contains(family) || otherFamilies.contains(family)
  }

  public func options(selected: String?) -> [DetectionOption] {
    var options = [DetectionOption(id: Self.systemID, label: t("option.system-monospace"))]
    options += monospaced.map { DetectionOption(id: $0, label: $0) }
    if let selected, !selected.isEmpty, !isInstalled(selected) {
      options.append(.notInstalled(selected, name: selected))
    }
    if !otherFamilies.isEmpty {
      options.append(DetectionOption(id: DetectionOption.dividerID, label: ""))
      options += otherFamilies.map { DetectionOption(id: $0, label: $0) }
    }
    return options
  }
}

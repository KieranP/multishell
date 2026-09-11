import Foundation
import MultishellCore

/// What a settings form shows for a setting the project does not override:
/// the value in force and where it came from; see docs/design/settings.md.
public struct InheritedSetting<Value: Equatable & Sendable>: Equatable, Sendable {
  public let value: Value
  /// The repository's file supplies it, rather than the user's global.
  public let isFromRepository: Bool

  public init(value: Value, isFromRepository: Bool) {
    self.value = value
    self.isFromRepository = isFromRepository
  }

  /// The caption under the row while the override is off. `shown` is the
  /// value as the row writes it, so one sentence serves every setting.
  public func caption(_ shown: String) -> String {
    isFromRepository
      ? t("inherited.from-repository", SharedProjectSettings.fileName, shown)
      : t("inherited.from-global", shown)
  }
}

/// The original, and still the common case.
public typealias InheritedFlag = InheritedSetting<Bool>

extension InheritedSetting where Value == Bool {
  public var caption: String {
    caption(value ? t("inherited.on") : t("inherited.off"))
  }
}

extension InheritedSetting where Value == WorktreeSortOrder {
  /// The label the picker gives it, so the caption and the row agree.
  public var caption: String { caption(value.displayName) }
}

import Foundation

/// Which terminal backend the app builds surfaces with. Applies to terminals
/// opened after the change; a running one keeps its engine.
public enum TerminalEngine: String, Codable, Hashable, Sendable, CaseIterable {
  case ghostty
  case swiftTerm

  public var displayName: String {
    switch self {
    case .ghostty: "Ghostty"
    case .swiftTerm: "SwiftTerm"
    }
  }
}

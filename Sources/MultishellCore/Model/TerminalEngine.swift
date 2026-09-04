import Foundation

/// Which terminal backend the app builds surfaces with.
///
/// Named here rather than in the GUI so the choice persists with the rest of
/// the workspace. It applies to terminals opened after the change; a running
/// terminal keeps the engine that started it.
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

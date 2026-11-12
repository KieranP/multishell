import Foundation

extension String {
  /// Trimmed of spaces and tabs, newlines kept, or `nil` where nothing is left.
  public var trimmedOrNil: String? {
    let trimmed = trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Trimmed of spaces, tabs and newlines, or `nil` where nothing is left.
  public var trimmedOfAllWhitespaceOrNil: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

import Foundation

extension String {
  /// Trimmed of spaces and tabs, newlines kept, or `nil` where nothing is left.
  public var trimmedOrNil: String? {
    let trimmed = trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? nil : trimmed
  }
}

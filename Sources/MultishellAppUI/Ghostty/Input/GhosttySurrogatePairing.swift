import Foundation

/// Joins an astral character an input method commits as two UTF-16 halves,
/// one `insertText` each, after Ghostty's own `LeadSurrogate`.
struct GhosttySurrogatePairing {
  private var lead: UTF16.CodeUnit?

  /// Empty while a lead waits for its trail; a trail with no lead is dropped,
  /// as Terminal drops it.
  mutating func text(for string: NSString) -> String {
    let unit = string.length == 1 ? string.character(at: 0) : nil
    if let unit, UTF16.isLeadSurrogate(unit) {
      lead = unit
      return ""
    }
    defer { lead = nil }
    if let unit, UTF16.isTrailSurrogate(unit) {
      return lead.map { String(decoding: [$0, unit], as: UTF16.self) } ?? ""
    }
    return string as String
  }
}

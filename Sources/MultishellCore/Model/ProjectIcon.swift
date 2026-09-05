import Foundation

/// What a project's sidebar glyph can be. The core stores a description,
/// never an image: an emoji is one string on every platform, and an SF
/// Symbol name is drawn by the Mac GUI from a list it knows how to render.
public enum ProjectIcon {
  public enum Kind: Hashable, Sendable {
    case folder
    case emoji(String)
    case symbol(String)
  }

  /// An emoji is anything with a scalar outside ASCII; a symbol name is
  /// ASCII letters, digits and dots. Whitespace around either is noise.
  public static func kind(of glyph: String?) -> Kind {
    guard let glyph else { return .folder }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .folder }
    if trimmed.unicodeScalars.allSatisfy(\.isASCII) {
      return symbols.contains(trimmed) ? .symbol(trimmed) : .folder
    }
    return .emoji(String(trimmed.prefix(1)))
  }

  /// The theme has sixteen slots; anything else is no tint.
  public static func validTint(_ slot: Int?) -> Int? {
    guard let slot, (0..<16).contains(slot) else { return nil }
    return slot
  }

  /// SwiftUI has no public symbol picker, so the choice is a curated list of
  /// symbols that read at sidebar size and exist on macOS 14.
  public static let symbols: [String] = [
    "folder", "folder.fill", "shippingbox", "cube", "cube.fill", "hammer", "wrench.and.screwdriver",
    "gearshape", "terminal", "chevron.left.forwardslash.chevron.right", "curlybraces",
    "server.rack",
    "cloud", "globe", "network", "antenna.radiowaves.left.and.right", "bolt", "flame", "leaf",
    "star", "heart", "flag", "tag", "bookmark", "book", "doc.text", "newspaper", "graduationcap",
    "building.2", "house", "cart", "creditcard", "banknote", "chart.bar", "chart.pie", "gauge",
    "iphone", "laptopcomputer", "desktopcomputer", "gamecontroller", "paintbrush", "camera",
    "music.note", "film", "puzzlepiece", "atom", "testtube.2", "lock", "key", "shield",
    "ant", "ladybug", "tortoise", "hare", "bird", "pawprint", "sparkles", "moon", "sun.max",
  ]
}

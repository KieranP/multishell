import Foundation

/// What a project's sidebar glyph can be. The core stores a description,
/// never an image: an SF Symbol name, or nothing, which is the folder.
public enum ProjectIcon {
  public enum Kind: Hashable, Sendable {
    case folder
    case symbol(String)

    /// The symbol name a GUI draws for this icon, so the three places that
    /// draw one need not each decide what the folder looks like.
    public var symbolName: String {
      switch self {
      case .folder: ProjectIcon.folderSymbol
      case .symbol(let name): name
      }
    }
  }

  /// A glyph is a symbol name from the palette; anything else is the folder,
  /// a repository's file being free to name one this build cannot draw.
  public static func kind(of glyph: String?) -> Kind {
    guard let glyph else { return .folder }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    return offered.contains(trimmed) ? .symbol(trimmed) : .folder
  }

  /// The glyph as a symbol name, or `nil`. A name this build lacks is still
  /// a name, a teammate's build drawing it; an emoji is not.
  public static func symbolName(_ glyph: String?) -> String? {
    guard let glyph else { return nil }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.unicodeScalars.allSatisfy(\.isASCII) else { return nil }
    return trimmed
  }

  /// What a project with no glyph is drawn as, and the palette's first cell.
  /// Picking it stores nothing, so the two share a picture, not a state.
  public static let folderSymbol = "folder"

  /// The theme has sixteen slots; anything else is no tint.
  public static func validTint(_ slot: Int?) -> Int? {
    guard let slot, (0..<16).contains(slot) else { return nil }
    return slot
  }

  /// A named row of the picker. SwiftUI has no public symbol picker, so the
  /// choice is a curated list in groups small enough to scan by shape.
  public struct Group: Hashable, Sendable {
    public let name: String
    public let glyphs: [String]

    public init(name: String, glyphs: [String]) {
      self.name = name
      self.glyphs = glyphs
    }
  }

  /// Groups matching the typed text, others cut to their matching symbols.
  /// `localizedStandardContains`, so translated group names fold accents.
  public static func symbolGroups(matching query: String) -> [Group] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return symbolGroups }
    return symbolGroups.compactMap { group in
      if group.name.localizedStandardContains(needle) { return group }
      let matches = group.glyphs.filter {
        $0.localizedStandardContains(needle)
          || searchWords[$0]?.localizedStandardContains(needle) == true
      }
      return matches.isEmpty ? nil : Group(name: group.name, glyphs: matches)
    }
  }
}

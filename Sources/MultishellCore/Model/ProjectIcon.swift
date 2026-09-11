import Foundation

/// What a project's sidebar glyph can be. The core stores a description,
/// never an image: an SF Symbol name the Mac GUI draws, from a list it knows
/// how to render, or nothing, which is the folder.
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

  /// A glyph is a symbol name from the palette. Whitespace around it is
  /// noise, and anything else is the folder, a repository's shared settings
  /// being free to name a glyph this build cannot draw.
  public static func kind(of glyph: String?) -> Kind {
    guard let glyph else { return .folder }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    return offered.contains(trimmed) ? .symbol(trimmed) : .folder
  }

  /// The glyph as a symbol name, or `nil` where it is not one. A name this
  /// build does not carry is still a name, a teammate on a newer build being
  /// able to draw it; an emoji, which no build draws any more, is not. This
  /// is what decides whether a stored glyph counts as a choice at all, so a
  /// leftover one neither masks the repository's icon nor is committed back
  /// into its file for the team.
  public static func symbolName(_ glyph: String?) -> String? {
    guard let glyph else { return nil }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.unicodeScalars.allSatisfy(\.isASCII) else { return nil }
    return trimmed
  }

  /// What a project with no glyph of its own is drawn as, and so also the
  /// palette's first cell: the picker offers the default's own picture as the
  /// way back to it. Picking that cell stores nothing rather than storing
  /// this, which is why `Kind.folder` and `.symbol(folderSymbol)` are the
  /// same picture and not the same state.
  public static let folderSymbol = "folder"

  /// The theme has sixteen slots; anything else is no tint.
  public static func validTint(_ slot: Int?) -> Int? {
    guard let slot, (0..<16).contains(slot) else { return nil }
    return slot
  }

  /// A named row of the picker. SwiftUI has no public symbol picker, so the
  /// choice is a curated list, in groups small enough to scan by shape
  /// rather than one alphabetical run of hundreds.
  public struct Group: Hashable, Sendable {
    public let name: String
    public let glyphs: [String]

    public init(name: String, glyphs: [String]) {
      self.name = name
      self.glyphs = glyphs
    }
  }

  /// The groups whose name matches the typed text, and every other group cut
  /// to the symbols whose own name or search words match. Empty text is the
  /// whole palette.
  public static func symbolGroups(matching query: String) -> [Group] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return symbolGroups }
    return symbolGroups.compactMap { group in
      if group.name.lowercased().contains(needle) { return group }
      let matches = group.glyphs.filter {
        $0.contains(needle) || searchWords[$0]?.contains(needle) == true
      }
      return matches.isEmpty ? nil : Group(name: group.name, glyphs: matches)
    }
  }
}

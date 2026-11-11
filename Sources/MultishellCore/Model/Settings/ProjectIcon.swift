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

  /// A named row of the picker. SwiftUI has no public symbol picker, so the
  /// choice is a curated list in groups small enough to scan by shape.
  public struct Group: Hashable, Sendable {
    public let name: String
    public let symbols: [String]
  }

  /// What a project with no glyph is drawn as, and the palette's first cell.
  /// Stored by name only to stand over a repository's glyph; either way it is `.folder`.
  public static let folderSymbol = "folder"

  /// A project's own "no tint", stored to stand over a repository's tint, as nothing
  /// would let it show through. Layering reads it as none, so no view meets it.
  static let noTint = -1

  /// A glyph is a symbol name from the palette; anything else is the folder,
  /// a repository's file being free to name one this build cannot draw.
  public static func kind(of glyph: String?) -> Kind {
    guard let name = normalizedGlyph(glyph), name != folderSymbol, offeredSymbols.contains(name)
    else { return .folder }
    return .symbol(name)
  }

  /// What a pick stores: the folder is nothing, unless a repository's glyph would
  /// show through nothing, where it is stored by name to stand over it.
  public static func storedGlyph(picking glyph: String?, over sharedGlyph: String?) -> String? {
    guard glyph == nil || glyph == folderSymbol else { return glyph }
    return normalizedGlyph(sharedGlyph) == nil ? nil : folderSymbol
  }

  /// The glyph as a symbol name, or `nil`. A name this build lacks is still
  /// a name, a teammate's build drawing it; an emoji is not.
  static func normalizedGlyph(_ glyph: String?) -> String? {
    guard let glyph else { return nil }
    let trimmed = glyph.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.unicodeScalars.allSatisfy(\.isASCII) else { return nil }
    return trimmed
  }

  /// What a pick stores: none is nothing, unless a repository's tint would show through.
  public static func storedTint(picking slot: Int?, over sharedTint: Int?) -> Int? {
    if let slot { return slot }
    return usableTint(sharedTint) == nil ? nil : noTint
  }

  /// A project's own tint as kept: a slot, or `noTint`.
  static func ownTint(_ slot: Int?) -> Int? {
    slot == noTint ? noTint : usableTint(slot)
  }

  /// A slot the theme lacks is no tint.
  static func usableTint(_ slot: Int?) -> Int? {
    guard let slot, (0..<Theme.ansiSlotCount).contains(slot) else { return nil }
    return slot
  }
}

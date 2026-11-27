import MultishellAppCore

/// The glyph a Files panel row or a Review file group draws: the one place a
/// file's look is decided, so an icon pack replaces this type.
enum FileIcon {
  static let file = "doc"

  static func symbol(for row: FileTreeRow) -> String {
    if row.isRepository { return "shippingbox" }
    return row.isFolder ? "folder" : file
  }
}

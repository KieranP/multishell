import MultishellAppCore

/// The glyph a Files panel row draws for a path: the one place a file's look
/// is decided, so an icon pack replaces one function.
enum FileIcon {
  static func symbol(for row: FileTreeRow) -> String {
    if row.isRepository { return "shippingbox" }
    return row.isFolder ? "folder" : "doc"
  }
}

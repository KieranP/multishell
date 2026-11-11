extension String {
  /// Whether this relative or absolute path lies below `folder`. By byte: a name
  /// starting with a combining mark joins the slash before it into one `Character`.
  public func isPath(under folder: String) -> Bool {
    let slash = UInt8(ascii: "/")
    // The Files filter asks this per path per keystroke; the buffers keep 200,000 at 9 ms.
    let compared = utf8.withContiguousStorageIfAvailable { path in
      folder.utf8.withContiguousStorageIfAvailable { prefix in
        path.count > prefix.count && path[prefix.count] == slash
          && path.prefix(prefix.count).elementsEqual(prefix)
      }
    }
    if let compared = compared ?? nil { return compared }
    let bytes = utf8
    let folderBytes = folder.utf8
    guard bytes.count > folderBytes.count, bytes.starts(with: folderBytes) else { return false }
    return bytes[bytes.index(bytes.startIndex, offsetBy: folderBytes.count)] == slash
  }
}

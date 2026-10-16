import Foundation

/// A file tab's file as it stands, read only within the size cap.
enum FileOnDisk: Sendable {
  case bytes(Data)
  /// Gone, or no longer a regular file.
  case gone
  case tooLarge(bytes: Int)

  /// Blocking: callers run it through `runOnDispatch`. Unmapped, as a mapped
  /// file truncated under the read faults; see worktrees.md.
  static func read(_ url: URL, sizeLimit: Int) -> Self {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true
    else { return .gone }
    let size = values.fileSize ?? 0
    guard size <= sizeLimit else { return .tooLarge(bytes: size) }
    guard let data = try? Data(contentsOf: url) else { return .gone }
    return data.count <= sizeLimit ? .bytes(data) : .tooLarge(bytes: data.count)
  }
}

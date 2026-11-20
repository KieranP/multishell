import Foundation

/// A file tab's file as it stands, read only within the size cap.
enum FileOnDisk: Sendable {
  case bytes(Data)
  /// Gone, or no longer a regular file.
  case gone
  case tooLarge(bytes: Int)
  /// There, but the read failed: no permission, or no descriptor left.
  case unreadable

  var bytes: Data? {
    if case .bytes(let data) = self { data } else { nil }
  }

  /// Blocking: callers run it through `runOnDispatch`. Unmapped, as a mapped
  /// file truncated under the read faults; see worktrees/line-count-badge.md.
  static func read(_ url: URL, sizeLimit: Int) -> Self {
    let values: URLResourceValues
    do {
      values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
    } catch {
      return goneOrUnreadable(after: error)
    }
    guard values.isRegularFile == true else { return .gone }
    let size = values.fileSize ?? 0
    guard size <= sizeLimit else { return .tooLarge(bytes: size) }
    do {
      let data = try Data(contentsOf: url)
      return data.count <= sizeLimit ? .bytes(data) : .tooLarge(bytes: data.count)
    } catch {
      return goneOrUnreadable(after: error)
    }
  }

  /// Only a missing file is gone; any other failure says nothing of whether it is there.
  private static func goneOrUnreadable(after error: any Error) -> Self {
    let error = error as NSError
    let isMissing =
      (error.domain == NSCocoaErrorDomain
        && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code))
      || (error.domain == NSPOSIXErrorDomain && [ENOENT, ENOTDIR].contains(Int32(error.code)))
    return isMissing ? .gone : .unreadable
  }

  /// Whether the disk spells `path`'s folders and name as given; one that ignores
  /// case opens `foo.txt` for `Foo.txt`. Blocking, and unknown reads as spelled so.
  static func isSpelledAsGiven(_ url: URL, path: String) -> Bool {
    guard let canonical = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath
    else { return true }
    let wanted = path.split(separator: "/")
    return Array(canonical.split(separator: "/").suffix(wanted.count)) == wanted
  }
}

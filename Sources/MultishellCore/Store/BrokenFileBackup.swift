import Foundation

/// Where a file that will not read is set aside: stamped beside it, and numbered
/// where one was already set aside that second, so none replaces another.
enum BrokenFileBackup {
  static func url(for fileURL: URL) -> URL {
    let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
      of: ":",
      with: "-",
    )
    let name = fileURL.deletingPathExtension()
    var backup = name.appendingPathExtension("\(stamp).broken.json")
    var copy = 2
    while FileManager.default.fileExists(atPath: backup.path) {
      backup = name.appendingPathExtension("\(stamp)-\(copy).broken.json")
      copy += 1
    }
    return backup
  }
}

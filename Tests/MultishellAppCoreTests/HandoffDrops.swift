import Foundation

/// The files Sends wrote under a drops directory, a folder for each Send.
enum HandoffDrops {
  static func files(in drops: URL) -> [URL] {
    let manager = FileManager.default
    let directories = (try? manager.contentsOfDirectory(atPath: drops.path)) ?? []
    return directories.flatMap { name in
      let directory = drops.appendingPathComponent(name, isDirectory: true)
      return ((try? manager.contentsOfDirectory(atPath: directory.path)) ?? []).map { file in
        directory.appendingPathComponent(file, isDirectory: false)
      }
    }
  }
}

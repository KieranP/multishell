import Foundation

extension Paths {
  /// This debug build's state file from before a cut name gained its hash, moved
  /// once to the name it has now; see Docs/develop/state-on-disk.md.
  static func carryOverStateFileFromBeforeTheHash() {
    #if DEBUG
      carryOverStateFileFromBeforeTheHash(named: bundledVariantName, in: stateDirectory)
    #endif
  }

  /// Left where a file already has the new name: that one is newer.
  static func carryOverStateFileFromBeforeTheHash(named name: String?, in directory: URL) {
    guard let name, !name.isEmpty else { return }
    let current = debugVariant(named: name)
    let cut = ".debug-" + String(name.prefix(14).map { $0.isPortableNameCharacter ? $0 : "-" })
    guard cut != current else { return }
    let before = directory.appendingPathComponent("state\(cut).json", isDirectory: false)
    let now = directory.appendingPathComponent("state\(current).json", isDirectory: false)
    guard !FileManager.default.fileExists(atPath: now.path) else { return }
    try? FileManager.default.moveItem(at: before, to: now)
  }
}

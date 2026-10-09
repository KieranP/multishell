import Foundation
import GhosttyKit

/// Config text loaded through a file, the only way libghostty reads one, deleted
/// once loaded. Freed once let go, as libghostty copies a config it is given.
final class GhosttyLoadedConfig {
  let config: ghostty_config_t
  /// libghostty's complaints, each naming the `.conf:` line it refused.
  let diagnostics: [String]

  private init(config: ghostty_config_t, diagnostics: [String]) {
    self.config = config
    self.diagnostics = diagnostics
  }

  /// `nil` where the text could not be written for libghostty to read, or
  /// libghostty made no config.
  static func load(
    _ text: String,
    in directory: URL = FileManager.default.temporaryDirectory,
  ) -> GhosttyLoadedConfig? {
    let file = directory.appendingPathComponent("ghostty-config-\(UUID().uuidString).conf")
    defer { try? FileManager.default.removeItem(at: file) }
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try text.write(to: file, atomically: true, encoding: .utf8)
    } catch {
      return nil
    }
    return finalized { ghostty_config_load_file($0, file.path) }
  }

  /// libghostty's own defaults, which need no file.
  static func defaults() -> GhosttyLoadedConfig? {
    finalized { _ in }
  }

  private static func finalized(_ fill: (ghostty_config_t) -> Void) -> GhosttyLoadedConfig? {
    GhosttyLibrary.initialize()
    guard let config = ghostty_config_new() else { return nil }
    fill(config)
    ghostty_config_finalize(config)
    let diagnostics = (0..<ghostty_config_diagnostics_count(config)).map { index in
      String(cString: ghostty_config_get_diagnostic(config, index).message)
    }
    return GhosttyLoadedConfig(config: config, diagnostics: diagnostics)
  }

  /// A boolean key as libghostty settled it, its default where unset;
  /// `nil` for a key it does not have.
  func flag(_ key: String) -> Bool? {
    var value = false
    let found = key.withCStringAndLength { ghostty_config_get(config, &value, $0, $1) }
    return found ? value : nil
  }

  deinit {
    ghostty_config_free(config)
  }
}

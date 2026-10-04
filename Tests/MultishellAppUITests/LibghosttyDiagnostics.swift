import Testing

@testable import MultishellAppUI

/// What libghostty refuses in config text, the config freed once read.
func libghosttyDiagnostics(_ text: String) throws -> [String] {
  let loaded = try #require(GhosttyLoadedConfig.load(text))
  defer { loaded.free() }
  return loaded.diagnostics
}

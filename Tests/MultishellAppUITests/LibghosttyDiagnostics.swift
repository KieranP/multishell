import Testing

@testable import MultishellAppUI

/// What libghostty refuses in config text.
func libghosttyDiagnostics(_ text: String) throws -> [String] {
  try #require(GhosttyLoadedConfig.load(text)).diagnostics
}

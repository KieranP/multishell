import Testing

@testable import MultishellCore

@Suite
struct OpenCodePluginReporterTests {
  @Test func theWrittenPluginHoldsNoNULByteSoGitReadsItAsText() {
    #expect(!OpenCodePlugin.source(helper: "/x").unicodeScalars.contains("\0"))
  }
}

import Testing

@testable import MultishellAppCore

@Suite
struct DebugThreadGroupTests {
  @Test func ghosttysThreadsAreTheTerminalsAndTheMainThreadStandsAlone() {
    #expect(DebugThreadGroup.of(threadNamed: "", isMain: true) == .main)
    for name in [
      "renderer", "io", "io-reader", "io-gather", "search", "cf_release", "CVDisplayLink",
    ] {
      #expect(DebugThreadGroup.of(threadNamed: name, isMain: false) == .terminals)
    }
    #expect(DebugThreadGroup.of(threadNamed: "com.apple.NSEventThread", isMain: false) == .other)
    #expect(DebugThreadGroup.of(threadNamed: "", isMain: false) == .other)
  }
}

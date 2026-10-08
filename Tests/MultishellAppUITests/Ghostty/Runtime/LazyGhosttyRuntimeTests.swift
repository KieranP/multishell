import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct LazyGhosttyRuntimeTests {
  @Test func aThemeAppliedBeforeAnyTerminalBuildsNoRuntime() {
    let reads = BaseReads()
    let lazyRuntime = LazyGhosttyRuntime(readBase: reads.read)

    lazyRuntime.apply(Theme.builtins[0], appearance: Appearance())

    #expect(reads.count == 0)
  }

  @Test func theRuntimeIsBuiltOnceOnFirstUseAndShared() {
    let reads = BaseReads()
    let lazyRuntime = LazyGhosttyRuntime(readBase: reads.read)

    let first = lazyRuntime.runtime

    #expect(lazyRuntime.runtime === first)
    #expect(reads.count == 1)
  }

  @Test func theRuntimeStartsWithTheUsersBase() {
    let lazyRuntime = LazyGhosttyRuntime(readBase: { "macos-auto-secure-input = false" })
    #expect(!lazyRuntime.runtime.secureInput.followsPasswordPrompts)
  }

  @MainActor
  private final class BaseReads {
    private(set) var count = 0

    func read() -> String {
      count += 1
      return ""
    }
  }
}

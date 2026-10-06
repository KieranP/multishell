import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttyRuntimeOwnerTests {
  @Test func aThemeAppliedBeforeAnyTerminalBuildsNoRuntime() {
    let reads = BaseReads()
    let owner = GhosttyRuntimeOwner(readBase: reads.read)

    owner.apply(Theme.builtins[0], appearance: Appearance())

    #expect(reads.count == 0)
  }

  @Test func theRuntimeIsBuiltOnceOnFirstUseAndShared() {
    let reads = BaseReads()
    let owner = GhosttyRuntimeOwner(readBase: reads.read)

    let first = owner.runtime

    #expect(owner.runtime === first)
    #expect(reads.count == 1)
  }

  @Test func theRuntimeStartsWithTheUsersBase() {
    let owner = GhosttyRuntimeOwner(readBase: { "macos-auto-secure-input = false" })
    #expect(!owner.runtime.secureInput.followsPasswordPrompts)
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

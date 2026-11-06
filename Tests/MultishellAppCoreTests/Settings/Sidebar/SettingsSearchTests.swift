import Testing

@testable import MultishellAppCore

@Suite
struct SettingsSearchTests {
  private static let terminal = [
    "Terminal", "Default shell:", "Open a terminal when a worktree is created",
  ]

  @Test func nothingTypedMatchesEveryPage() {
    #expect(SettingsSearch.matches("", terms: Self.terminal))
    #expect(SettingsSearch.matches("   ", terms: []))
  }

  @Test func aWordMatchesInsideAnyTermIgnoringCaseAndAccents() {
    #expect(SettingsSearch.matches("SHELL", terms: Self.terminal))
    #expect(SettingsSearch.matches("crÉated", terms: Self.terminal))
    #expect(!SettingsSearch.matches("theme", terms: Self.terminal))
  }

  @Test func everyWordTypedMustMatchThoughNotInTheSameTerm() {
    #expect(SettingsSearch.matches("default created", terms: Self.terminal))
    #expect(!SettingsSearch.matches("default font", terms: Self.terminal))
  }

  @Test func theSidebarListsEveryPageUntilSomethingIsTypedThenOnlyThoseMatching() {
    let terms: (SettingsPage) -> [String] = { $0 == .appearance ? ["Theme"] : ["Other"] }

    #expect(
      SettingsSearch.pages(in: .allProjects, matching: "", terms: terms)
        == SettingsPage.pages(in: .allProjects)
    )
    #expect(
      SettingsSearch.pages(in: .allProjects, matching: "theme", terms: terms) == [.appearance]
    )
  }
}

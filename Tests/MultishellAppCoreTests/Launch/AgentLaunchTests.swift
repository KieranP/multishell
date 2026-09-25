import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AgentLaunchTests {
  /// A dropped file is named to the agent the way its prompt reads one;
  /// the catalogue says so only where that is known.
  @Test func theCatalogueSaysWhichAgentsReadFileMentions() {
    #expect(AgentCatalogue.agent("claude")?.fileMentionPrefix == "@")
    #expect(AgentCatalogue.agent("codex")?.fileMentionPrefix == nil)
  }

  @Test func resumeUsesTheCatalogueOrGivesUp() {
    let claude = AgentCatalogue.agent("claude")!
    #expect(AgentLaunch.arguments(for: claude, resume: false) == ["claude"])
    #expect(AgentLaunch.arguments(for: claude, resume: true) == ["claude", "--continue"])
    let gemini = AgentCatalogue.agent("gemini")!
    #expect(AgentLaunch.arguments(for: gemini, resume: true) == ["gemini", "--resume", "latest"])
    // Every agent in the catalogue resumes today, so the no-flag arm is
    // shown against a descriptor rather than left uncovered.
    let flagless = AgentDescriptor(
      id: "flagless", name: "Flagless", executable: "flagless", mark: .monogram("Fl"))
    #expect(
      AgentLaunch.arguments(for: flagless, resume: true) == nil, "no resume flag: plain shell")
  }
}

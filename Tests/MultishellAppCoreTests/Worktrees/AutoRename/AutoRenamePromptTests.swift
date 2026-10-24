import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct AutoRenamePromptTests {
  @Test func thePromptCarriesTheBranchItsSubjectsStatAndDiff() {
    let material = RenameMaterial(
      branch: "kp/billing-export",
      subjects: ["Add CSV export", "Seed billing"],
      diffstat: "export.swift | 4 ++++",
      diff: "+let csv = true\n",
      isDiffCut: false,
    )
    let prompt = AutoRenamePrompt.text(for: material)
    #expect(prompt.contains("Branch: kp/billing-export"))
    #expect(prompt.contains("- Add CSV export\n- Seed billing"))
    #expect(prompt.contains("export.swift | 4 ++++"))
    #expect(prompt.contains("The diff:\n+let csv = true"))
  }

  @Test func aCutDiffIsSaidToBeCut() {
    let material = RenameMaterial(
      branch: nil,
      subjects: ["Big"],
      diffstat: "a | 1",
      diff: "+a\n",
      isDiffCut: true,
    )
    #expect(AutoRenamePrompt.text(for: material).contains("The diff, cut short:"))
  }

  @Test func onlyStagedWorkLeavesOutTheSubjects() {
    let material = RenameMaterial(
      branch: nil,
      subjects: [],
      diffstat: "a | 1",
      diff: "+a\n",
      isDiffCut: false,
    )
    #expect(!AutoRenamePrompt.text(for: material).contains("Commit subjects"))
  }
}

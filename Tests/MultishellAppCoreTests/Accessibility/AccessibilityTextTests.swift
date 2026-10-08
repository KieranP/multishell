import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextTests {
  @Test func theChipAndARowSayBackgroundShellsApartFromSubagents() {
    let out = [
      Worker(id: "a", type: "Explore"),
      Worker(id: "shell:500", type: nil, pid: 500),
      Worker(id: "shell:501", type: nil, pid: 501),
    ]
    #expect(
      AccessibilityText.workers(out)
        == "1 subagent, 2 background shells, Explore, background shell, background shell")
    #expect(
      AccessibilityText.pane(
        SidebarPane(
          id: UUID(), title: "claude", position: nil, isFocused: false, state: .running,
          workers: out, agentID: nil, agentName: nil))
        == "claude, tab, Working, 1 subagent, 2 background shells")
  }

  @Test func theChipSaysEachWorkersNameAndDescriptionAndWhichFailed() {
    var failed = Worker(id: "a2", type: "Explore", description: "Map the hooks")
    failed.hasFailed = true
    let out = [
      Worker(id: "a0", type: "general-purpose", name: "code-review", description: "Review"),
      Worker(id: "a1", type: "general-purpose", description: "Reuse angle", parentID: "a0"),
      failed,
    ]
    #expect(
      AccessibilityText.workers(out)
        == "2 subagents, 1 failed, code-review: Review, "
        + "general-purpose: Reuse angle under code-review, "
        + "Explore: Map the hooks failed")
  }

  @Test func theChipSaysEachNestedWorkerUnderItsParent() {
    let out = [
      Worker(id: "a0", type: "general-purpose", name: "code-review"),
      Worker(id: "a1", type: "general-purpose", name: "Reuse angle", parentID: "a0"),
      Worker(id: "a2", type: "Explore"),
    ]
    #expect(
      AccessibilityText.workers(out)
        == "3 subagents, code-review, Reuse angle under code-review, Explore")
  }
}

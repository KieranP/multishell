import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@MainActor
@Suite
struct AppModelAllChangesOpeningTests {
  @Test func theChangesPagesButtonOpensTheTabInFrontWithTheKeyboard() throws {
    let harness = Harness()
    harness.model.select(harness.main)

    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == tab.id)
    #expect(harness.model.takeFileTabFocusRequest(tab.id))
  }

  @Test func aSecondOpenTurnsToTheTabTheWorktreeHas() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let first = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.newTab()

    let again = harness.model.openAllChangesTab(in: harness.main.id)

    #expect(again?.id == first.id)
    #expect(harness.model.workspace.allChangesTabs.count == 1)
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == first.id)
  }

  @Test func aWorktreeNotListedOpensNothing() {
    let harness = Harness()

    #expect(harness.model.openAllChangesTab(in: "/repos/gone") == nil)
    #expect(harness.model.workspace.allChangesTabs.isEmpty)
  }

  @Test func itsBadgeCountsEveryFilesCommentsToSendInItsWorktreeOnly() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let comments = ["a.swift", "b.swift", "b.swift"].map { path in
      ReviewComment(
        path: path,
        side: .onDisk,
        scope: .modified,
        lines: 1...1,
        quote: ["x"],
        text: "Look.",
      )
    }
    for comment in comments { harness.model.addReviewComment(comment, in: harness.main.id) }
    harness.model.addReviewComment(comments[0], in: harness.feature.id)
    harness.model.markReviewCommentsSent(
      [comments[2].id],
      in: harness.main.id,
      to: "Codex",
      at: Date(),
    )

    #expect(harness.model.pendingReviewCommentCount(of: tab) == 2)
  }

  @Test func itIsListedInTheSwitcherAndChoosingItTurnsToIt() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.select(harness.feature)

    let row = harness.model.quickSwitcherPanesAndFileTabs().first { $0.kind == .allChangesTab }
    harness.model.toggleQuickSwitcher(.tabs)
    harness.model.chooseQuickSwitcherRow(.allChangesTab(tab.id))

    #expect(row?.target == .allChangesTab(tab.id))
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.activeWorkspaceTab(in: harness.main.id)?.id == tab.id)
  }
}

import Foundation
import MultishellCore
import MultishellGitKit
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore

@Suite(.serialized) @MainActor
struct AppModelFileTabLayoutTests {
  @Test func aFileWithLinesAddedAndRemovedSplitsAndAnUnchangedOneStaysUnified() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, main) = try harness.openFileTab()
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }

    harness.model.setFileTabLayout(.split)
    #expect(harness.model.layout(of: tab) == .unified, "nothing changed to put side by side")

    try "changed\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(tab.id)
    try await waitUntil { harness.model.changeKind(of: tab) == .modified }

    #expect(harness.model.layout(of: tab) == .split)
  }

  @Test func theLayoutChosenInOneTabIsTheLayoutOfEveryFileOpenedAfter() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (first, main) = try harness.openFileTab()
    try "changed\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.noteFileTabChanged(first.id)
    try await waitUntil { harness.model.changeKind(of: first) == .modified }
    harness.model.setFileTabLayout(.split)
    harness.model.closeTab(first.id)

    let second = try #require(harness.store.openFileTab(path: "README.md", in: main.id))
    harness.model.reconcileSessions(takingFocus: true)
    try await waitUntil { harness.model.fileTabReadings[second.id] != nil }

    #expect(harness.model.layout(of: second) == .split)
  }

  @Test func aFileOfAdditionsAloneStaysUnifiedWhateverTheLayoutChosen() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (readme, main) = try harness.openFileTab()
    try "changed\n".write(
      to: main.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    try "new\n".write(to: main.path.appending(path: "new.txt"), atomically: true, encoding: .utf8)
    harness.model.noteFileTabChanged(readme.id)
    try await waitUntil { harness.model.changeKind(of: readme) == .modified }
    harness.model.setFileTabLayout(.split)
    #expect(harness.model.offersLayoutSwitch(for: readme))

    let new = try #require(harness.store.openFileTab(path: "new.txt", in: main.id))
    harness.model.reconcileSessions(takingFocus: true)
    try await waitUntil { harness.model.changeKind(of: new) == .added }

    #expect(harness.model.changeKind(of: new) == .added)
    #expect(harness.model.layout(of: new) == .unified)
    #expect(!harness.model.offersLayoutSwitch(for: new))
  }

  @Test func aSwitchToSplitKeepsTheSelectedMatchOnItsLine() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    let kept = "foo first kept\nfoo second kept\n"
    try await TestRepository.commit(
      "notes",
      files: ["notes.txt": "foo " + String(repeating: "x", count: 200) + "\n" + kept],
      in: main.path,
      using: harness.git,
    )
    try ("bar\n" + kept).write(
      to: main.path.appending(path: "notes.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let (tab, _) = try harness.openFileTab("notes.txt")
    try await waitUntil { harness.model.fileTabReadings[tab.id] != nil }
    harness.model.showFind()
    harness.model.setFindText("foo", of: tab.id)
    harness.model.findNext(in: tab.id)
    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 1)

    harness.model.setFileTabLayout(.split)

    #expect(harness.model.layout(of: tab) == .split)
    #expect(harness.model.selectedFileFindMatch(of: tab.id) == 0, "foo first kept")
  }
}

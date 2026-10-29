import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelControlQuickSwitcherTests {
  private static func titles(in reply: ControlReply?) -> [String] {
    let sections = reply?.outputFields["sections"] as? [[String: Any]] ?? []
    return sections.flatMap { $0["rows"] as? [[String: Any]] ?? [] }
      .compactMap { $0["title"] as? String }
  }

  private func harnessWithCommands() -> Harness {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["Terminal", "Split Right"], isEnabled: true, isChecked: false),
      PlatformMenuItem(path: ["Terminal", "Split Down"], isEnabled: true, isChecked: false),
    ]
    return harness
  }

  @Test func itOpensWithNoKeyWindowAndListsWhatTheTextMatches() async {
    let harness = harnessWithCommands()
    harness.platform.isWorkspaceWindowKey = false

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "commands", text: "split", step: nil, choosesSelected: false)
      )
    )

    #expect(harness.model.quickSwitcher?.scope == .commands)
    #expect(reply?.outputFields["text"] as? String == "split")
    #expect(Self.titles(in: reply) == ["Split Down", "Split Right"])
  }

  @Test func anArrowThenReturnChoosesTheRowItLandsOn() async {
    let harness = harnessWithCommands()

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "commands", text: "split", step: .next, choosesSelected: true)
      )
    )

    #expect(reply == .done)
    #expect(harness.platform.performedMenuItems == [["Terminal", "Split Right"]])
    #expect(
      harness.platform.chosenMenuItems.isEmpty,
      "a click's deferred choice is not a request's",
    )
    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func aScopeItHasNoButtonForIsRefused() async {
    let harness = harnessWithCommands()

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "everything", text: nil, step: nil, choosesSelected: false)
      )
    )

    #expect(reply == .refused(.invalidValue(key: "--scope", value: "everything")))
  }

  @Test func returnWithNoRowListedIsRefused() async {
    let harness = harnessWithCommands()

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "commands", text: "zzzz", step: nil, choosesSelected: true)
      )
    )

    #expect(reply == .refused(.noSwitcherRow))
  }

  @Test func choosingAFileThatWouldNotOpenIsRefusedWithNoBeep() async throws {
    let harness = harnessWithCommands()
    try Data([0x00]).write(to: harness.main.path.appending(path: "image.bin"))
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: ["image.bin"],
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "files", text: "image", step: nil, choosesSelected: true)
      )
    )

    #expect(reply == .refused(.fileNotOpenable(path: "image.bin")))
    #expect(harness.platform.beeps == 0)
  }

  @Test func choosingAProjectWithNoWorktreeIsRefusedWithNoBeep() async throws {
    let harness = harnessWithCommands()
    let empty = harness.root.appendingPathComponent("zebra", isDirectory: true)
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    harness.store.addProject(at: empty)

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "all", text: "zebra", step: nil, choosesSelected: true)
      )
    )

    #expect(reply == .refused(.projectWithNoWorktree(id: ControlID.project(empty.path))))
    #expect(harness.platform.beeps == 0)
    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func aCommandGreyedOutSinceItWasListedIsRefused() async {
    let harness = harnessWithCommands()
    _ = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(
          scope: "commands",
          text: "split down",
          step: nil,
          choosesSelected: false,
        )
      )
    )
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["Terminal", "Split Down"], isEnabled: false, isChecked: false)
    ]

    let reply = await harness.messageSource.ask(
      .quickSwitcher(QuickSwitcherOrder(scope: nil, text: nil, step: nil, choosesSelected: true))
    )

    #expect(reply == .refused(.menuItemDisabled(path: "Terminal > Split Down")))
  }

  @Test func aFileIsChosenOnceTheWorktreesFilesAreRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)

    let reply = await harness.model.answer(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "files", text: "README", step: nil, choosesSelected: true)
      )
    )

    #expect(reply == .done)
    #expect(harness.model.workspace.fileTabs.map(\.path) == ["README.md"])
  }

  @Test func aChoiceWaitsForAListingStillBeingBuilt() async {
    let harness = harnessWithCommands()
    harness.model.trackedFiles[harness.main.id] = TrackedFiles(
      paths: (0..<30_000).map { "src/file\($0).txt" },
      submodulePaths: [],
      notCheckedOutPaths: [],
      isCapped: false,
    )

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "files", text: "file29999", step: nil, choosesSelected: true)
      )
    )

    #expect(reply == .refused(.fileNotOpenable(path: "src/file29999.txt")))
  }

  @Test func choosingAWorktreeWhoseFolderIsGoneAnswersWithItsAlert() async throws {
    let harness = harnessWithCommands()
    try FileManager.default.removeItem(at: harness.feature.path)

    let reply = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(scope: "worktrees", text: "feature", step: nil, choosesSelected: true)
      )
    )

    guard case .alert? = reply?.refusal else {
      Issue.record("not the missing folder's alert: \(String(describing: reply))")
      return
    }
    #expect(harness.model.worktreeInView?.id == harness.main.id)
  }

  @Test func withTheMainWindowShutNothingOpens() async {
    let harness = harnessWithCommands()
    harness.platform.isWorkspaceWindowVisible = false

    let reply = await harness.messageSource.ask(
      .quickSwitcher(QuickSwitcherOrder(scope: nil, text: nil, step: nil, choosesSelected: false))
    )

    #expect(reply == .refused(.noWindow))
    #expect(harness.model.quickSwitcher == nil)
  }

  @Test func aRefusedCommandLeavesTheSwitcherUp() async {
    let harness = harnessWithCommands()
    _ = await harness.messageSource.ask(
      .quickSwitcher(
        QuickSwitcherOrder(
          scope: "commands",
          text: "split down",
          step: nil,
          choosesSelected: false,
        )
      )
    )
    harness.platform.menuItems = [
      PlatformMenuItem(path: ["Terminal", "Split Down"], isEnabled: false, isChecked: false)
    ]

    _ = await harness.messageSource.ask(
      .quickSwitcher(QuickSwitcherOrder(scope: nil, text: nil, step: nil, choosesSelected: true))
    )

    #expect(harness.model.quickSwitcher != nil)
  }
}

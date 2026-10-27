import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextQuickSwitcherTests {
  @Test func aWaitingAgentsRowSaysHowLongItHasWaited() {
    let since = Date(timeIntervalSince1970: 1_000)
    let item = QuickSwitcherItem(
      target: .pane(UUID()),
      kind: .agent(id: "claude"),
      title: "Retry backoff",
      location: "billing-api › Webhook retries",
      state: .attention,
      since: since,
    )

    let spoken = AccessibilityText.quickSwitcherRow(item, at: since.addingTimeInterval(240))

    #expect(spoken.contains("Retry backoff"))
    #expect(spoken.contains(SessionState.attention.displayName))
    #expect(spoken.contains(t("spoken.elapsed", "4m")))
  }

  @Test func aCommandsRowSaysItsKeysAndWhetherItIsTicked() {
    let item = QuickSwitcherItem(
      target: .command(path: ["View", "Files Panel"]),
      kind: .command,
      title: "Files Panel",
      location: "View",
      shortcut: "⇧⌘E",
      isChecked: true,
    )

    let spoken = AccessibilityText.quickSwitcherRow(item, at: .now)

    #expect(spoken.contains("⇧⌘E"))
    #expect(spoken.contains(t("spoken.checked")))
  }

  @Test func aLocationsStepsAreSpokenAsAListNotAsTheirMark() {
    let item = QuickSwitcherItem(
      target: .command(path: ["View", "Panels", "Files"]),
      kind: .command,
      title: "Files",
      location: QuickSwitcherItem.path(["View", "Panels"]),
    )

    #expect(AccessibilityText.quickSwitcherRow(item, at: .now) == "Files, View, Panels")
  }

  @Test func anIdleRowSaysNoState() {
    let item = QuickSwitcherItem(
      target: .pane(UUID()),
      kind: .shell,
      title: "zsh",
      location: "multishell › main",
      state: .idle,
    )

    #expect(AccessibilityText.quickSwitcherRow(item, at: .now) == "zsh, multishell, main")
  }

  @Test func aPaneOfASplitSaysWhichPaneItIs() {
    let item = QuickSwitcherItem(
      target: .pane(UUID()),
      kind: .shell,
      title: "api",
      location: "multishell › main",
      position: PanePosition(number: 2, count: 3),
    )

    let spoken = AccessibilityText.quickSwitcherRow(item, at: .now)

    #expect(spoken.contains(t("spoken.pane-position", 2, 3)))
  }
}

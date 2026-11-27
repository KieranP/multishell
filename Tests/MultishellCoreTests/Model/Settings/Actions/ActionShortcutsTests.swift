import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ActionShortcutsTests {
  private let controlOptionS = KeyCombination(.character("s"), [.control, .option])

  @Test func keysGivenToASecondActionLeaveTheFirstWithNone() {
    var shortcuts = ActionShortcuts()
    shortcuts.set(controlOptionS, for: "Start Server")
    shortcuts.set(controlOptionS, for: "Seed Database")

    #expect(shortcuts.keys(for: "Start Server") == nil)
    #expect(shortcuts.name(holding: controlOptionS) == "Seed Database")
  }

  @Test func aRenamedActionKeepsItsKeysAndClearedOnesAreFreeAgain() {
    var shortcuts = ActionShortcuts()
    shortcuts.set(controlOptionS, for: "Start Server")

    shortcuts.rename("Start Server", to: "Serve")
    #expect(shortcuts.keys(for: "Serve") == controlOptionS)

    shortcuts.set(nil, for: "Serve")
    #expect(shortcuts == ActionShortcuts())
  }

  @Test func readBackEachEntryIsSpelledAndARefusedOrSecondClaimCostsThatEntryAlone() throws {
    let decoded = try decodeJSON(
      ActionShortcuts.self,
      #"""
      {
        "A Serve": "ctrl+alt+s",
        "B Seed": "ctrl+alt+s",
        "C Interrupt": "ctrl+c",
        "D Garbled": "cmd+nonsense",
        "E Number": 4
      }
      """#,
    )

    #expect(decoded.keys(for: "A Serve") == controlOptionS)
    #expect(decoded.keys(for: "B Seed") == nil)
    #expect(decoded.keys(for: "C Interrupt") == nil)
    let roundTripped = try JSONDecoder().decode(
      ActionShortcuts.self,
      from: try JSONEncoder().encode(decoded),
    )
    #expect(roundTripped == decoded)
  }
}

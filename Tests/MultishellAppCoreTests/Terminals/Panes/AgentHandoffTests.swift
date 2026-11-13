import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct AgentHandoffTests {
  @Test func eachHandoffIsWrittenIntoADirectoryOfItsOwnUnderTheDrops() throws {
    let drops = Scratch.path("handoff-drops")
    defer { Scratch.remove(drops) }

    let first = try AgentHandoff.write("one", named: "review-main.md", in: drops)
    let second = try AgentHandoff.write("two", named: "review-main.md", in: drops)

    #expect(first.lastPathComponent == "review-main.md")
    #expect(first.deletingLastPathComponent().deletingLastPathComponent() == drops)
    #expect(first != second)
    #expect(try String(contentsOf: first, encoding: .utf8) == "one")
    #expect(try String(contentsOf: second, encoding: .utf8) == "two")
  }

  @Test func anEntryWithNoQuoteHasNoIndentedBlock() {
    let entry = AgentHandoffEntry(heading: "Lint", caveat: nil, quote: [], text: "Fix the lint.")

    let document = AgentHandoff.document(introduction: "Intro.", entries: [entry])

    #expect(document == "Intro.\n\n## Lint\n\nFix the lint.\n")
  }
}

import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SupportTests {
  @Test func aPathIsUnderABaseByWholeComponentOnly() {
    let base = URL(fileURLWithPath: "/a/b", isDirectory: true)
    #expect(URL(fileURLWithPath: "/a/b/c/d").pathComponents(under: base) == ["c", "d"])
    #expect(URL(fileURLWithPath: "/a/b").pathComponents(under: base) == [])
    #expect(URL(fileURLWithPath: "/a/bc").pathComponents(under: base) == nil)
    #expect(URL(fileURLWithPath: "/x").pathComponents(under: URL(fileURLWithPath: "/")) == ["x"])
  }

  @Test func aLineListDropsBlanksAndCommentsAndTrimsTheRest() {
    #expect(LineList.entries(in: " a \n\n# no\nb\r\n") == ["a", "b"])
    #expect(LineList.entries(in: "   \n\n").isEmpty)
  }

  @Test func theHomeDirectoryAbbreviatesToWhateverTheCallerStandsItFor() {
    #expect("/Users/me/x".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME")
    #expect("/Users/me/Work/x".abbreviatingHomeDirectory(home: "/Users/me") == "~/Work/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me") == "~")
    #expect("/Users/meg/x".abbreviatingHomeDirectory(home: "/Users/me") == "/Users/meg/x")
    #expect("/tmp/x".abbreviatingHomeDirectory(home: "/Users/me") == "/tmp/x")
  }

  @Test func aNeighbourWrapsAtBothEndsAndAnArrayOfOneHasNone() {
    struct Item: Identifiable { let id: Int }
    let items = [Item(id: 1), Item(id: 2), Item(id: 3)]
    #expect(items.neighbour(of: 3, .after)?.id == 1)
    #expect(items.neighbour(of: 1, .before)?.id == 3)
    #expect(items.neighbour(of: 2, .after)?.id == 3)
    #expect(items.neighbour(of: 9, .after) == nil)
    #expect([Item(id: 1)].neighbour(of: 1, .after) == nil)
  }

  @Test func clampedHoldsAValueInsideTheRange() {
    #expect(5.clamped(to: 0...3) == 3)
    #expect((-1).clamped(to: 0...3) == 0)
    #expect(2.5.clamped(to: 0...3) == 2.5)
  }
}

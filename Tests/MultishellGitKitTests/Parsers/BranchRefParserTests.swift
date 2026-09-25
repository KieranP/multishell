import Foundation
import Testing

@testable import MultishellGitKit

@Suite
struct BranchRefParserTests {
  @Test func branchRefsCarryTheirTipAndWhetherTheirUpstreamIsGone() {
    let output = """
      refs/heads/main\tab1\trefs/remotes/origin/main\t
      refs/heads/feat\tcd2\trefs/remotes/origin/feat\t[ahead 1]\t\t1700000000
      refs/heads/squashed\tef3\trefs/remotes/origin/squashed\t[gone]
      refs/heads/local-only\t004\t\t
      refs/remotes/origin/main\tab1\t\t
      refs/remotes/origin/HEAD\tab1\t\t\trefs/remotes/origin/main
      """
    let refs = BranchRefParser.parse(output)
    let byName = Dictionary(uniqueKeysWithValues: refs.map { ($0.fullName, $0) })

    #expect(refs.count == 6)
    #expect(byName[BranchRef.originHead]?.symref == "refs/remotes/origin/main")
    #expect(byName["refs/heads/main"]?.symref == nil)
    #expect(byName["refs/heads/feat"]?.tip == "cd2")
    #expect(byName["refs/heads/feat"]?.isUpstreamGone == false)
    #expect(byName["refs/heads/squashed"]?.isUpstreamGone == true)
    #expect(byName["refs/heads/local-only"]?.upstream == nil)
    #expect(byName["refs/heads/local-only"]?.isUpstreamGone == false)
    #expect(byName["refs/remotes/origin/main"]?.isRemote == true)
    // The date is the sixth field, so every row written before it existed
    // simply has none; the badges never read it.
    #expect(
      byName["refs/heads/feat"]?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(byName["refs/heads/main"]?.committedAt == nil)
  }

  /// A date git could not print, or one from a build that formatted it
  /// differently, costs the date and not the row.
  @Test func aRefWhoseDateIsNotANumberKeepsTheRest() {
    let refs = BranchRefParser.parse("refs/heads/main\tab1\t\t\t\tMon Jan 1 2024\n")
    #expect(refs.count == 1)
    #expect(refs[0].tip == "ab1")
    #expect(refs[0].committedAt == nil)
  }

  @Test func aRowWithoutANameOrATipIsDroppedAndTheRestSurvive() {
    let refs = BranchRefParser.parse(
      "refs/heads/main\tab1\t\t\r\nnonsense\n\t\tx\t\nrefs/heads/feat\tcd2\t\t\r\n")
    #expect(refs.map(\.fullName) == ["refs/heads/main", "refs/heads/feat"])
    // The \r a Windows-configured checkout appends is not part of the tip.
    #expect(refs[0].tip == "ab1")
  }
}

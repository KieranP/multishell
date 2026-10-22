import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellHighlight

@Suite
struct DiffHighlightingTests {
  private static let commentedOut = [
    DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "/*"),
    DiffLine(kind: .context, oldNumber: 2, newNumber: 1, text: "let x = 1"),
    DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "*/"),
  ]

  private static func role(
    of word: String,
    in text: DiffDisplayText,
    spans: [HighlightSpan],
  )
    -> HighlightRole?
  {
    let location = (text.string as NSString).range(of: word).location
    return spans.last { $0.range.contains(location) }?.role
  }

  @Test func aSplitsCommittedSideIsColouredByHeadsTextAlone() async {
    let left = SplitDiff(Self.commentedOut).committed

    let spans = await DiffHighlighting.spans(for: left, path: "a.swift")

    #expect(Self.role(of: "let", in: left, spans: spans) == .comment)
  }

  @Test func aSplitsOnDiskSideIsColouredByTheFileOnDiskAlone() async {
    let right = SplitDiff(Self.commentedOut).onDisk

    let spans = await DiffHighlighting.spans(for: right, path: "a.swift")

    #expect(Self.role(of: "let", in: right, spans: spans) == .keyword)
  }

  @Test func anInjectionOnARemovedRowBelowAKeptOneIsHighlighted() async {
    let unified = DiffDisplayText([
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "<script>let a</script>"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "<script>var b</script>"),
    ])

    let spans = await DiffHighlighting.spans(for: unified, path: "a.html")

    #expect(Self.role(of: "let", in: unified, spans: spans) == .keyword)
    #expect(Self.role(of: "var", in: unified, spans: spans) == .keyword)
  }

  @Test func aShebangAddedOnDiskNamesTheLanguageThoughHeadsLineIsListedFirst() async {
    let unified = DiffDisplayText([
      DiffLine(kind: .removed, oldNumber: 1, newNumber: nil, text: "set -e"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "#!/bin/bash"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "echo hi"),
    ])

    let spans = await DiffHighlighting.spans(for: unified, path: "deploy")

    #expect(Self.role(of: "#!", in: unified, spans: spans) == .comment)
  }
}

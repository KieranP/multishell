import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct ChangedPartsMarkerTests {
  private static func run(removed: [String], added: [String]) -> [DiffLine] {
    removed.enumerated().map { index, text in
      DiffLine(kind: .removed, oldNumber: index + 1, newNumber: nil, text: text)
    }
      + added.enumerated().map { index, text in
        DiffLine(kind: .added, oldNumber: nil, newNumber: index + 1, text: text)
      }
  }

  private static func markedText(_ lines: [DiffLine]) -> [[String]] {
    lines.map { line in
      line.changedParts.map { String(decoding: Array(line.text.utf16)[$0], as: UTF16.self) }
    }
  }

  @Test func eachLineCarriesTheWordsOfItsRunThatChanged() {
    let lines = [
      DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "keep"),
      DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "let a = 1"),
      DiffLine(kind: .removed, oldNumber: 3, newNumber: nil, text: "let b = 2"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "let a = 10"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 3, text: "let b = 20"),
      DiffLine(kind: .added, oldNumber: nil, newNumber: 4, text: "let c = 3"),
    ]

    let marked = ChangedPartsMarker.marking(lines)

    #expect(marked.map(\.changedParts) == [[], [8..<9], [8..<9], [8..<10], [8..<10], []])
  }

  @Test func wordsARewrapMovedBetweenLinesStillMatchAndWhatChangedIsMarked() {
    let lines = Self.run(
      removed: [
        "`Cargo.lock` TOML. The shebang is the file on disk's, which a unified diff",
        "lists after `HEAD`'s first line.",
      ],
      added: [
        "`Cargo.lock` TOML, `Package.resolved`, `.prettierrc` and `.swift-format` JSON.",
        "The shebang is the file on disk's, which a unified diff lists after `HEAD`'s",
        "first line.",
      ],
    )

    let markedText = Self.markedText(ChangedPartsMarker.marking(lines))

    #expect(markedText[0].isEmpty)
    #expect(markedText[2].contains { $0.contains("`Package.resolved`") })
    #expect(!markedText[3].contains { $0.contains("shebang") })
    #expect(markedText[4].isEmpty)
  }

  @Test func aLongRunOfEditedLinesIsMarkedLineByLine() {
    let removed = (0..<900).map { "let value\($0) = compute(input: items[\($0)], scale: 2)" }
    let added = removed.map { $0.replacingOccurrences(of: "scale: 2", with: "scale: 3") }
    #expect(
      WordDiff.changedParts(
        from: removed.joined(separator: "\n"),
        to: added.joined(separator: "\n"),
      ) == .tooLongToCompare
    )

    let marked = Self.markedText(
      ChangedPartsMarker.marking(Self.run(removed: removed, added: added))
    )

    #expect(marked.allSatisfy { $0 == ["2"] || $0 == ["3"] })
  }

  @Test func aChangedLineFollowedByNewLinesIsMarkedAndTheNewLinesAreNot() {
    let lines = Self.run(
      removed: ["let total = items.count"],
      added: ["let total = items.count + 1", "print(total)", "log(total)", "return total"],
    )

    let marked = Self.markedText(ChangedPartsMarker.marking(lines))

    #expect(marked == [[], [" + 1"], [], [], []])
  }

  @Test func aRewrapThatOnlyMovedTheBreaksMarksNothing() {
    let lines = Self.run(
      removed: ["the quick brown fox", "jumps over the lazy dog"],
      added: ["the quick", "brown fox jumps over the lazy dog"],
    )

    #expect(ChangedPartsMarker.marking(lines).allSatisfy { $0.changedParts.isEmpty })
  }

  @Test func aLineChangedWholeKeepsNoMarksInACRLFFileEither() {
    let lines = Self.run(
      removed: ["keep1 keep2 keep3\r", "old words\r", "keep4 keep5\r"],
      added: ["keep1 keep2 keep3\r", "new stuff\r", "keep4 keep5\r"],
    )

    #expect(ChangedPartsMarker.marking(lines).allSatisfy { $0.changedParts.isEmpty })
  }

  @Test func aLineChangedWholeButForAnIdeographicSpaceKeepsNoMarks() {
    let lines = Self.run(
      removed: ["keep1 keep2 keep3", "\u{3000}old words"],
      added: ["keep1 keep2 keep3", "\u{3000}new stuff"],
    )

    #expect(ChangedPartsMarker.marking(lines).allSatisfy { $0.changedParts.isEmpty })
  }
}

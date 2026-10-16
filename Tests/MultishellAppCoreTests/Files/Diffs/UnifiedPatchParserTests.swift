import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct UnifiedPatchParserTests {
  private static func parse(_ patch: String, encoding: String.Encoding = .utf8) -> ParsedPatch {
    UnifiedPatchParser.parse(Data(patch.utf8), encoding: encoding)
  }

  @Test func eachLineKeepsItsKindAndBothNumbers() {
    let patch = """
      diff --git a/a.txt b/a.txt
      index 1..2 100644
      --- a/a.txt
      +++ b/a.txt
      @@ -1,3 +1,3 @@
       one
      -two
      +TWO
       three

      """

    #expect(
      Self.parse(patch)
        == .lines([
          DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "one"),
          DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "two"),
          DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "TWO"),
          DiffLine(kind: .context, oldNumber: 3, newNumber: 3, text: "three"),
        ])
    )
  }

  @Test func aNewFilesEmptySideStillNumbersFromOneAndTheNoNewlineMarkIsNoRow() {
    let patch =
      "--- /dev/null\n+++ b/n.txt\n@@ -0,0 +1,2 @@\n+a\n+b\n\\ No newline at end of file\n"

    #expect(
      Self.parse(patch)
        == .lines([
          DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "a"),
          DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "b"),
        ])
    )
  }

  @Test func aCarriageReturnIsNotShownAndAHeaderLookalikeInTheFileIsText() {
    let patch = "@@ -1,2 +1,2 @@\n x\r\n-@@ -9 +9 @@\n+--- b/z\n"

    #expect(
      Self.parse(patch)
        == .lines([
          DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "x"),
          DiffLine(kind: .removed, oldNumber: 2, newNumber: nil, text: "@@ -9 +9 @@"),
          DiffLine(kind: .added, oldNumber: nil, newNumber: 2, text: "--- b/z"),
        ])
    )
  }

  @Test func aBinaryAModeOnlyAndAnEmptyPatchSaySo() {
    #expect(Self.parse("diff --git a/i b/i\nBinary files a/i and b/i differ\n") == .binary)
    #expect(Self.parse("diff --git a/s b/s\nold mode 100644\nnew mode 100755\n") == .modeOnly)
    #expect(Self.parse("") == .unchanged)
  }

  @Test func aLineIsDecodedInTheFilesOwnEncoding() {
    var patch = Data("@@ -1 +1 @@\n+caf".utf8)
    patch.append(0xE9)
    patch.append(Data("\n".utf8))

    #expect(
      UnifiedPatchParser.parse(patch, encoding: .isoLatin1)
        == .lines([
          DiffLine(kind: .added, oldNumber: nil, newNumber: 1, text: "café")
        ])
    )
  }

  @Test func aFileSwappedForASymlinkReadsAsItsTwoSectionsRowsAlone() {
    let patch = """
      diff --git a/tc.txt b/tc.txt
      deleted file mode 100644
      index 1..0
      --- a/tc.txt
      +++ /dev/null
      @@ -1,2 +0,0 @@
      -one
      -two
      diff --git a/tc.txt b/tc.txt
      new file mode 120000
      index 0..2
      --- /dev/null
      +++ b/tc.txt
      @@ -0,0 +1 @@
      +clean.txt
      \\ No newline at end of file

      """

    guard case .lines(let lines) = Self.parse(patch) else {
      Issue.record("no rows")
      return
    }
    #expect(lines.map(\.text) == ["one", "two", "clean.txt"])
    #expect(lines.map(\.kind) == [.removed, .removed, .added])
  }
}

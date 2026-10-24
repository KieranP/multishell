import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct FilePathTextTests {
  private let directory = URL(fileURLWithPath: "/repos/demo", isDirectory: true)

  @Test func aShellGetsAbsolutePaths() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")],
      relativeTo: directory,
    )
    #expect(text == "/repos/demo/Sources/App.swift")
  }

  @Test func aShellGetsAPathWithASpaceQuotedForTheShell() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")],
      relativeTo: directory,
    )
    #expect(text == "'/repos/demo/My Notes.md'")
  }

  @Test func aBackslashEndingANameCannotCarryTheNextOutOfItsQuotes() {
    let text = FilePathText.pastedText(
      for: [
        URL(fileURLWithPath: #"/repos/demo/a\"#),
        URL(fileURLWithPath: "/repos/demo/x; touch pwned; #"),
      ],
      relativeTo: directory,
    )
    #expect(text == #"'/repos/demo/a'\\'' '/repos/demo/x; touch pwned; #'"#)
  }

  @Test func anAgentGetsAMentionRelativeToTheSessionsDirectory() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@Sources/App.swift")
  }

  @Test func aMentionOfAFileOutsideTheDirectoryStaysAbsolute() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/elsewhere/notes.md")],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@/elsewhere/notes.md")
  }

  /// An empty mention names nothing, so the directory itself is spelled out.
  @Test func aMentionOfTheDirectoryItselfStaysAbsolute() {
    let text = FilePathText.pastedText(
      for: [directory],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@/repos/demo")
  }

  /// A mention ends at whitespace; a quote would be a character in the
  /// prompt rather than quoting.
  @Test func aMentionEscapesASpaceRatherThanQuotingIt() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@My\\ Notes.md")
  }

  @Test func severalFilesAreOneSpaceSeparatedLineWithNoNewline() {
    let text = FilePathText.pastedText(
      for: [
        URL(fileURLWithPath: "/repos/demo/a.swift"),
        URL(fileURLWithPath: "/repos/demo/b.swift"),
      ],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@a.swift @b.swift")
  }

  /// A terminal acts on a newline or an escape in a name, pressing Return or reading a
  /// sequence, and no quoting reaches through.
  @Test func aNameATerminalWouldActOnIsLeftOut() {
    let awkward = URL(fileURLWithPath: "/repos/demo/two\nlines.md")
    let plain = URL(fileURLWithPath: "/repos/demo/a.swift")

    #expect(FilePathText.pastedText(for: [awkward], relativeTo: directory) == nil)
    #expect(
      FilePathText.pastedText(for: [awkward], relativeTo: directory, mentionPrefix: "@") == nil,
      "not even as a mention",
    )
    #expect(
      FilePathText.pastedText(for: [awkward, plain], relativeTo: directory, mentionPrefix: "@")
        == "@a.swift",
      "the rest of the drop still goes in",
    )
    #expect(
      FilePathText.pastedText(
        for: [URL(fileURLWithPath: "/repos/demo/\u{1b}[31m.md")],
        relativeTo: directory,
      ) == nil,
      "an escape sequence in a name is not pasted either",
    )
    for control in ["\u{7f}", "\u{9b}"] {
      let name = URL(fileURLWithPath: "/repos/demo/a\(control)b.md")
      #expect(FilePathText.pastedText(for: [name], relativeTo: directory) == nil)
    }
  }

  @Test func severalPathsForAShellAreOneLineOfQuotedWords() {
    let text = FilePathText.pastedText(
      for: [
        URL(fileURLWithPath: "/repos/demo/a.swift"),
        URL(fileURLWithPath: "/repos/demo/My Notes.md"),
      ],
      relativeTo: directory,
    )
    #expect(text == "/repos/demo/a.swift '/repos/demo/My Notes.md'")
  }

  @Test func aMentionOutsideTheDirectoryWithASpaceIsAbsoluteAndEscaped() {
    let text = FilePathText.pastedText(
      for: [
        URL(fileURLWithPath: "/repos/demo/Sources/App.swift"),
        URL(fileURLWithPath: "/drops/shot one.png"),
      ],
      relativeTo: directory,
      mentionPrefix: "@",
    )
    #expect(text == "@Sources/App.swift @/drops/shot\\ one.png")
  }

  @Test func aMentionPastedWithNoDirectoryIsAbsolute() {
    let text = FilePathText.pastedText(
      for: [URL(fileURLWithPath: "/repos/demo/a.swift")],
      relativeTo: nil,
      mentionPrefix: "@",
    )
    #expect(text == "@/repos/demo/a.swift")
  }

  @Test func aMentionThroughASymlinkOfTheDirectoryStaysRelative() throws {
    let scratch = try Scratch.directory("symlinked")
    defer { Scratch.remove(scratch) }
    let real = scratch.appendingPathComponent("real", isDirectory: true)
    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    let link = scratch.appendingPathComponent("link", isDirectory: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    try FileManager.default.createDirectory(
      at: real.appendingPathComponent("Sources"),
      withIntermediateDirectories: true,
    )
    try Data().write(to: real.appendingPathComponent("Sources/App.swift"))

    let text = FilePathText.pastedText(
      for: [link.appendingPathComponent("Sources/App.swift")],
      relativeTo: real,
      mentionPrefix: "@",
    )

    #expect(text == "@Sources/App.swift")
  }

  @Test func noFilesAreNothing() {
    #expect(FilePathText.pastedText(for: [], relativeTo: directory) == nil)
    #expect(FilePathText.pastedText(for: [], relativeTo: directory, mentionPrefix: "@") == nil)
  }
}

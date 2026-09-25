import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct FileDropTextTests {
  private let directory = URL(fileURLWithPath: "/repos/demo", isDirectory: true)

  @Test func aShellGetsAbsolutePathsQuotedAndATrailingSpace() {
    let text = FileDropText.text(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")], relativeTo: directory)
    #expect(text == "/repos/demo/Sources/App.swift ")
  }

  @Test func aShellGetsAPathWithASpaceQuotedForTheShell() {
    let text = FileDropText.text(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")], relativeTo: directory)
    #expect(text == "'/repos/demo/My Notes.md' ")
  }

  @Test func aBackslashEndingANameCannotCarryTheNextOutOfItsQuotes() {
    let text = FileDropText.text(
      for: [
        URL(fileURLWithPath: #"/repos/demo/a\"#),
        URL(fileURLWithPath: "/repos/demo/x; touch pwned; #"),
      ], relativeTo: directory)
    #expect(text == #"'/repos/demo/a'\\'' '/repos/demo/x; touch pwned; #' "#)
  }

  @Test func anAgentGetsAMentionRelativeToTheSessionsDirectory() {
    let text = FileDropText.text(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@Sources/App.swift ")
  }

  @Test func aMentionOfAFileOutsideTheDirectoryStaysAbsolute() {
    let text = FileDropText.text(
      for: [URL(fileURLWithPath: "/elsewhere/notes.md")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@/elsewhere/notes.md ")
  }

  /// An empty mention names nothing, so the directory itself is spelled out.
  @Test func aMentionOfTheDirectoryItselfStaysAbsolute() {
    let text = FileDropText.text(for: [directory], relativeTo: directory, mentionPrefix: "@")
    #expect(text == "@/repos/demo ")
  }

  /// A mention ends at whitespace; a quote would be a character in the
  /// prompt rather than quoting.
  @Test func aMentionEscapesASpaceRatherThanQuotingIt() {
    let text = FileDropText.text(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@My\\ Notes.md ")
  }

  @Test func severalFilesAreOneSpaceSeparatedLineWithNoNewline() {
    let text = FileDropText.text(
      for: [
        URL(fileURLWithPath: "/repos/demo/a.swift"),
        URL(fileURLWithPath: "/repos/demo/b.swift"),
      ],
      relativeTo: directory, mentionPrefix: "@")
    #expect(text == "@a.swift @b.swift ")
    #expect(!text.contains("\n"), "a drop leaves something to read, it does not submit")
  }

  /// A terminal acts on a newline or an escape in a name, pressing Return or reading a
  /// sequence, and no quoting reaches through.
  @Test func aNameATerminalWouldActOnIsLeftOut() {
    let awkward = URL(fileURLWithPath: "/repos/demo/two\nlines.md")
    let plain = URL(fileURLWithPath: "/repos/demo/a.swift")

    #expect(FileDropText.text(for: [awkward], relativeTo: directory).isEmpty)
    #expect(
      FileDropText.text(for: [awkward], relativeTo: directory, mentionPrefix: "@").isEmpty,
      "not even as a mention")
    #expect(
      FileDropText.text(for: [awkward, plain], relativeTo: directory, mentionPrefix: "@")
        == "@a.swift ", "the rest of the drop still goes in")
    #expect(
      FileDropText.text(
        for: [URL(fileURLWithPath: "/repos/demo/\u{1b}[31m.md")], relativeTo: directory
      )
      .isEmpty, "an escape sequence in a name is not pasted either")
  }

  @Test func aDropOfNothingIsNothing() {
    #expect(FileDropText.text(for: [], relativeTo: directory).isEmpty)
    #expect(FileDropText.text(for: [], relativeTo: directory, mentionPrefix: "@").isEmpty)
  }
}

import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct FilePathTextTests {
  private let directory = URL(fileURLWithPath: "/repos/demo", isDirectory: true)

  @Test func aShellGetsAbsolutePathsQuotedAndATrailingSpace() {
    let text = FilePathText.droppedText(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")], relativeTo: directory)
    #expect(text == "/repos/demo/Sources/App.swift ")
  }

  @Test func aShellGetsAPathWithASpaceQuotedForTheShell() {
    let text = FilePathText.droppedText(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")], relativeTo: directory)
    #expect(text == "'/repos/demo/My Notes.md' ")
  }

  @Test func aBackslashEndingANameCannotCarryTheNextOutOfItsQuotes() {
    let text = FilePathText.droppedText(
      for: [
        URL(fileURLWithPath: #"/repos/demo/a\"#),
        URL(fileURLWithPath: "/repos/demo/x; touch pwned; #"),
      ], relativeTo: directory)
    #expect(text == #"'/repos/demo/a'\\'' '/repos/demo/x; touch pwned; #' "#)
  }

  @Test func anAgentGetsAMentionRelativeToTheSessionsDirectory() {
    let text = FilePathText.droppedText(
      for: [URL(fileURLWithPath: "/repos/demo/Sources/App.swift")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@Sources/App.swift ")
  }

  @Test func aMentionOfAFileOutsideTheDirectoryStaysAbsolute() {
    let text = FilePathText.droppedText(
      for: [URL(fileURLWithPath: "/elsewhere/notes.md")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@/elsewhere/notes.md ")
  }

  /// An empty mention names nothing, so the directory itself is spelled out.
  @Test func aMentionOfTheDirectoryItselfStaysAbsolute() {
    let text = FilePathText.droppedText(for: [directory], relativeTo: directory, mentionPrefix: "@")
    #expect(text == "@/repos/demo ")
  }

  /// A mention ends at whitespace; a quote would be a character in the
  /// prompt rather than quoting.
  @Test func aMentionEscapesASpaceRatherThanQuotingIt() {
    let text = FilePathText.droppedText(
      for: [URL(fileURLWithPath: "/repos/demo/My Notes.md")], relativeTo: directory,
      mentionPrefix: "@")
    #expect(text == "@My\\ Notes.md ")
  }

  @Test func severalFilesAreOneSpaceSeparatedLineWithNoNewline() {
    let text = FilePathText.droppedText(
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

    #expect(FilePathText.droppedText(for: [awkward], relativeTo: directory).isEmpty)
    #expect(
      FilePathText.droppedText(for: [awkward], relativeTo: directory, mentionPrefix: "@").isEmpty,
      "not even as a mention")
    #expect(
      FilePathText.droppedText(for: [awkward, plain], relativeTo: directory, mentionPrefix: "@")
        == "@a.swift ", "the rest of the drop still goes in")
    #expect(
      FilePathText.droppedText(
        for: [URL(fileURLWithPath: "/repos/demo/\u{1b}[31m.md")], relativeTo: directory
      )
      .isEmpty, "an escape sequence in a name is not pasted either")
  }

  @Test func pastedFilesAreQuotedPathsWithNoTrailingSpace() {
    let text = FilePathText.pastedText(for: [
      URL(fileURLWithPath: "/repos/demo/a.swift"), URL(fileURLWithPath: "/repos/demo/My Notes.md"),
    ])
    #expect(text == "/repos/demo/a.swift '/repos/demo/My Notes.md'")
  }

  @Test func aPasteOfOnlyNamesATerminalWouldActOnIsNothing() {
    #expect(FilePathText.pastedText(for: [URL(fileURLWithPath: "/repos/demo/two\nlines")]) == nil)
    #expect(FilePathText.pastedText(for: []) == nil)
  }

  @Test func aDropOfNothingIsNothing() {
    #expect(FilePathText.droppedText(for: [], relativeTo: directory).isEmpty)
    #expect(FilePathText.droppedText(for: [], relativeTo: directory, mentionPrefix: "@").isEmpty)
  }
}

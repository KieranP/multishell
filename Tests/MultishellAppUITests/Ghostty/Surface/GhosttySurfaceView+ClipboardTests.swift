import AppKit
import GhosttyKit
import TestScratch
import Testing

@testable import MultishellAppUI
@testable import MultishellCore

@Suite
@MainActor
struct GhosttySurfaceViewClipboardTests {
  private static let pasteKeybind = "keybind = ctrl+shift+v=paste_from_clipboard"

  private func pasteKey() throws -> ControlKey {
    try #require(ControlKey(parsing: "ctrl-shift-v"))
  }

  /// The press a keyboard event sends; `keyDown` itself goes through AppKit's
  /// input system, which a test process without `NSApp` cannot run.
  private func pressPasteKeyAsTheUser(on view: GhosttySurfaceView) throws {
    view.sendUserInput(try #require(GhosttyKeyInput(try pasteKey(), GHOSTTY_ACTION_PRESS)))
  }

  private func withPanes(
    _ count: Int = 1,
    keybind: String = pasteKeybind,
    typing: @escaping ([URL]) -> String? = { $0.map(\.path).joined(separator: " ") },
    _ body: ([GhosttySurfaceView], Recorder<[URL]>, URL) throws -> Void,
  ) throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }
    let runtime = GhosttyRuntime(readBase: { GhosttyUserConfig.base(userContents: [keybind]) })
    let typed = Recorder<[URL]>()
    let views = try (0..<count).map { _ in
      let view = GhosttySurfaceView(runtime: runtime, launch: .sleeping)
      try #require(view.surface != nil)
      view.pasteboard = pasteboard
      view.dropsDirectory = drops
      view.textForPastedFiles = { files in
        typed.record(files)
        return typing(files)
      }
      return view
    }
    defer {
      for view in views { view.freeSurface() }
    }
    try body(views, typed, drops)
  }

  @Test func aPasteFromTheEditMenuHandsACopiedImageToTheSessionAsAFile() throws {
    try withPanes { views, typed, drops throws in
      views[0].paste(nil)

      #expect(typed.received.count == 1)
      #expect(typed.received.first?.first?.path.hasPrefix(drops.path + "/") == true)
    }
  }

  @Test func aMiddleClickPasteHandsACopiedImageToTheSessionAsAFile() throws {
    try withPanes { views, typed, drops throws in
      let click = try #require(
        CGEvent(
          mouseEventSource: nil,
          mouseType: .otherMouseDown,
          mouseCursorPosition: .zero,
          mouseButton: .center,
        ).flatMap(NSEvent.init(cgEvent:))
      )

      views[0].otherMouseDown(with: click)

      #expect(typed.received.count == 1)
      #expect(typed.received.first?.first?.path.hasPrefix(drops.path + "/") == true)
    }
  }

  @Test func aKeyTheUserBoundToPasteHandsACopiedImageToTheSessionAsAFile() throws {
    try withPanes { views, typed, drops throws in
      try pressPasteKeyAsTheUser(on: views[0])

      #expect(typed.received.count == 1)
      #expect(typed.received.first?.first?.path.hasPrefix(drops.path + "/") == true)
    }
  }

  @Test func aKeyBoundToPasteInEveryPaneHandsEachTheSameImage() throws {
    let everyPane = "keybind = all:ctrl+shift+v=paste_from_clipboard"
    try withPanes(2, keybind: everyPane) { views, typed, _ throws in
      try pressPasteKeyAsTheUser(on: views[1])

      #expect(typed.received.count == 2)
      #expect(Set(typed.received.flatMap(\.self)).count == 1)
    }
  }

  @Test func theSameKeyPressedFromTheCommandLineSavesNoImage() throws {
    try withPanes { views, typed, drops throws in
      #expect(views[0].press([try pasteKey()]))

      #expect(typed.received.isEmpty)
      #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).isEmpty)
    }
  }

  @Test func theSameKeyPressedFromTheCommandLineAfterTheUsersPasteSavesNoSecondFile() throws {
    try withPanes { views, typed, drops throws in
      views[0].paste(nil)
      #expect(views[0].press([try pasteKey()]))

      #expect(typed.received.count == 1)
      #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).count == 1)
    }
  }

  @Test func aPasteTheCommandLineMakesThroughTheMenuSavesNoImage() throws {
    try withPanes { views, typed, drops throws in
      GhosttySurfaceView.actingForTheCommandLine { views[0].paste(nil) }

      #expect(typed.received.isEmpty)
      #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).isEmpty)
    }
  }

  /// A program's OSC 52 read reaches the view on libghostty's tick, after
  /// any key of the user's has returned; the test sandbox runs no program.
  @Test func aClipboardReadOutsideTheUsersInputSavesNoImage() throws {
    try withPanes { views, typed, drops throws in
      let result = views[0].answerClipboardRequest(
        GhosttyClipboardRequest(handle: nil, wantsText: true),
        at: GHOSTTY_CLIPBOARD_STANDARD,
      )

      #expect(result == GHOSTTY_CLIPBOARD_READ_UNAVAILABLE)
      #expect(typed.received.isEmpty)
      #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).isEmpty)
    }
  }
}

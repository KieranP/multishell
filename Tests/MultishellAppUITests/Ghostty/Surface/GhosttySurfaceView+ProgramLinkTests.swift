import AppKit
import Carbon.HIToolbox
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttySurfaceViewProgramLinkTests {
  private func withPane(_ body: (GhosttySurfaceView) throws -> Void) throws {
    let view = GhosttySurfaceView(runtime: GhosttyRuntime(), launch: .sleeping)
    try #require(view.surface != nil)
    defer { view.freeSurface() }
    try body(view)
  }

  private func click(_ type: NSEvent.EventType, _ flags: NSEvent.ModifierFlags) throws -> NSEvent {
    try #require(
      NSEvent.mouseEvent(
        with: type,
        location: NSPoint(x: 10, y: 10),
        modifierFlags: flags,
        timestamp: 1,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1,
      )
    )
  }

  private func commandKey(_ flags: NSEvent.ModifierFlags) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .flagsChanged,
        location: .zero,
        modifierFlags: flags,
        timestamp: 1,
        windowNumber: 0,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: false,
        keyCode: UInt16(kVK_Command),
      )
    )
  }

  @Test func aProgramLinkTurnsLibghosttysArrowIntoAHand() throws {
    try withPane { view in
      view.pointer = .arrow
      view.programLinkUnderPointer = "Sources/A.swift"

      #expect(view.shownPointer == .pointingHand)
    }
  }

  @Test func aShapeTheProgramAskedForIsKeptOverALink() throws {
    try withPane { view in
      view.pointer = .crosshair
      view.programLinkUnderPointer = "Sources/A.swift"

      #expect(view.shownPointer == .crosshair)
    }
  }

  @Test func aPaneWhoseProgramHoldsNoMouseShowsNoProgramLink() throws {
    try withPane { view in
      view.programLinkUnderPointer = "Sources/A.swift"

      view.judgeProgramLink(at: NSPoint(x: 40, y: 40), isCommandHeld: true)

      let isForgotten = view.programLinkUnderPointer == nil
      #expect(isForgotten)
    }
  }

  @Test func aPointerDraggedOutOfThePaneIsOverNoLink() throws {
    try withPane { view in
      view.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
      view.programLinkUnderPointer = "Sources/A.swift"

      view.judgeProgramLink(at: NSPoint(x: 250, y: 50), isCommandHeld: true)

      let isForgotten = view.programLinkUnderPointer == nil && view.judgedPointerCell == nil
      #expect(isForgotten)
    }
  }

  @Test func aPointersCellIsCountedFromThePanesTopAsLibghosttyCountsRows() throws {
    try withPane { view in
      view.frame = NSRect(x: 0, y: 0, width: 200, height: 100)

      let pixel = view.pixelFromTopLeft(of: NSPoint(x: 10, y: 90))

      #expect(pixel == view.convertToBacking(CGPoint(x: 10, y: 10)))
    }
  }

  @Test func aCommandClickOnAProgramLinkOpensItInThePanesDirectory() throws {
    try withPane { view in
      var opened: [GhosttyClickedLink] = []
      view.onLinkClick = { opened.append($0) }
      view.programLinkUnderPointer = "Sources/A.swift:12"

      view.mouseDown(with: try click(.leftMouseDown, .command))
      view.mouseUp(with: try click(.leftMouseUp, .command))

      let expected = GhosttyClickedLink(
        text: "Sources/A.swift:12",
        directory: view.currentDirectory,
        isHyperlink: false,
      )
      #expect(opened == [expected])
    }
  }

  @Test func aPlainClickOnAProgramLinkIsLeftToTheProgram() throws {
    try withPane { view in
      var opened: [GhosttyClickedLink] = []
      view.onLinkClick = { opened.append($0) }
      view.programLinkUnderPointer = "Sources/A.swift"

      view.mouseDown(with: try click(.leftMouseDown, []))
      view.mouseUp(with: try click(.leftMouseUp, []))

      #expect(opened.isEmpty)
    }
  }

  @Test func aCommandPressDraggedOffItsLinkOpensNothing() throws {
    try withPane { view in
      var opened: [GhosttyClickedLink] = []
      view.onLinkClick = { opened.append($0) }
      view.programLinkUnderPointer = "Sources/A.swift"

      view.mouseDown(with: try click(.leftMouseDown, .command))
      view.programLinkUnderPointer = nil
      view.mouseUp(with: try click(.leftMouseUp, .command))

      #expect(opened.isEmpty)
    }
  }

  @Test func aPlainPressDisarmsALinkWhoseReleaseNeverCame() throws {
    try withPane { view in
      view.pressedProgramLink = "Sources/A.swift"

      view.mouseDown(with: try click(.leftMouseDown, []))

      let isDisarmed = view.pressedProgramLink == nil
      #expect(isDisarmed)
    }
  }

  @Test func lettingGoOfCommandTakesTheHandAway() throws {
    try withPane { view in
      view.programLinkUnderPointer = "Sources/A.swift"

      view.flagsChanged(with: try commandKey([]))

      let isForgotten = view.programLinkUnderPointer == nil
      #expect(isForgotten)
    }
  }
}

import AppKit
import Foundation
import SwiftUI
import Testing

@testable import MultishellAppUI
@testable import MultishellCore
@testable import MultishellServices

@Suite @MainActor
struct ThemeServiceColorsTests {
  private let theme: Theme
  private var palette: AreaPalette { theme.projectsPanel }

  init() throws {
    let json = """
      { "id": "x", "name": "X", "ui": {
        "ci": { "passed": "#00ff00", "failed": "#ff0000", "running": "#0000ff", "on_hold": "#ffff00" },
        "projects_panel": { "text_secondary": "#808080" } } }
      """
    theme = try JSONDecoder().decode(Theme.self, from: Data(json.utf8))
  }

  private func hex(_ color: Color) throws -> Int {
    let srgb = try #require(NSColor(color).usingColorSpace(.sRGB))
    let channel = { (value: CGFloat) in Int((value * 255).rounded()) }
    return channel(srgb.redComponent) << 16 | channel(srgb.greenComponent) << 8
      | channel(srgb.blueComponent)
  }

  @Test func anUnknownStatusIsTheAreasGreyAsACancelledOneIs() throws {
    #expect(try hex(theme.color(for: .unknown, on: palette)) == 0x808080)
    #expect(try hex(theme.color(for: .cancelled, on: palette)) == 0x808080)
  }

  @Test func aKnownStatusTakesItsOwnCIColour() throws {
    #expect(try hex(theme.color(for: CIRunStatus.failed, on: palette)) == 0xff0000)
    #expect(try hex(theme.color(for: CIRunStatus.passed, on: palette)) == 0x00ff00)
  }
}

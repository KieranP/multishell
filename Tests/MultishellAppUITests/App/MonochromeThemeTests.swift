import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

/// Every colour of a theme set to one value leaves nothing else on screen: a
/// pixel of any other colour is something the theme does not reach.
@Suite(.serialized) @MainActor
struct MonochromeThemeTests {
  private enum Scene: CaseIterable {
    case agentBoard, debugInfo, worktreeWithFilesPanelAndFilter
  }

  /// A glyph a menu's button style draws is colour-matched once more, landing
  /// a step off: 254 for 255. Two steps is rounding, not a colour of its own.
  private static func matches(_ drawn: RGB, _ expected: RGB) -> Bool {
    [(drawn.red, expected.red), (drawn.green, expected.green), (drawn.blue, expected.blue)]
      .allSatisfy { abs(Int($0) - Int($1)) <= 2 }
  }

  /// The base theme's file with every colour replaced by `hex`, saved as
  /// `mono.json`, reloaded and chosen.
  private func applyTheme(allOf hex: String, to harness: ModelHarness) async throws {
    let base = try #require(Theme.builtinFile(named: "multishell.dark"))
    var text = try String(contentsOf: base, encoding: .utf8)
    text = text.replacingOccurrences(
      of: ##""#[0-9a-fA-F]{3,8}""##,
      with: #""\#(hex)""#,
      options: .regularExpression,
    )
    text = text.replacingOccurrences(of: #""multishell.dark""#, with: #""mono""#)
    let themes = harness.model.themesDirectory
    try FileManager.default.createDirectory(at: themes, withIntermediateDirectories: true)
    try Data(text.utf8).write(to: themes.appendingPathComponent("mono.json"))
    await harness.model.reloadThemes()
    harness.model.setTheme("mono")
  }

  private func show(_ scene: Scene, in harness: ModelHarness, worktree: Worktree) {
    switch scene {
    case .agentBoard:
      harness.model.showAgentBoard()

    case .debugInfo:
      harness.model.setDebugToolsEnabled(true)
      harness.model.showDebugInfo()

    case .worktreeWithFilesPanelAndFilter:
      _ = harness.model.select(worktree)
      harness.model.newShellTab()
      harness.model.setShowsFilesPanel(true)
      harness.model.setShowsSidebarFilter(true)
    }
  }

  private func strayColours(allOf hex: String) async throws -> [String] {
    var strays: [String] = []
    for scene in Scene.allCases {
      let harness = ModelHarness()
      let worktree = harness.addPrimaryWorktree()
      try await applyTheme(allOf: hex, to: harness)
      show(scene, in: harness, worktree: worktree)
      let window = HStack(spacing: 0) {
        SidebarView(model: harness.model).frame(width: 260)
        ResizeHandle(
          width: .constant(260),
          range: 200...400,
          initial: 260,
          dragged: SidebarWidth.dragged,
          palette: harness.model.currentTheme.projectsPanel,
        )
        DetailView(model: harness.model)
      }
      let bitmap = try #require(
        OffscreenWindow.pixels(ofHosted: window, size: CGSize(width: 1100, height: 600))
      )
      let expected = try #require(HexColor.parse(hex))
      var found: [String: (x: Int, y: Int)] = [:]
      for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
          guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
          let rgb = RGB(
            red: UInt8((pixel.redComponent * 255).rounded()),
            green: UInt8((pixel.greenComponent * 255).rounded()),
            blue: UInt8((pixel.blueComponent * 255).rounded()),
          )
          if !Self.matches(rgb, expected), found[rgb.opaqueHex] == nil {
            found[rgb.opaqueHex] = (x, y)
          }
        }
      }
      strays += found.prefix(8).map { "\(scene) \($0.key) at \($0.value)" }
    }
    return strays
  }

  @Test func anAllWhiteThemeDrawsNothingButWhite() async throws {
    let strays = try await strayColours(allOf: "#ffffff")
    #expect(strays.isEmpty, "\(strays.joined(separator: "\n"))")
  }

  @Test func anAllBlackThemeDrawsNothingButBlack() async throws {
    let strays = try await strayColours(allOf: "#000000")
    #expect(strays.isEmpty, "\(strays.joined(separator: "\n"))")
  }
}

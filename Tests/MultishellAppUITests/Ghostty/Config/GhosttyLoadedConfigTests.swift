import Foundation
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyLoadedConfigTests {
  @Test func theFileIsGoneOnceLibghosttyHasReadIt() throws {
    let directory = ScratchDirectory.path("ghostty-config-file")
    defer { ScratchDirectory.remove(directory) }

    let loaded = try #require(
      GhosttyLoadedConfig.load("macos-auto-secure-input = false", in: directory))
    defer { loaded.free() }

    #expect(loaded.flag("macos-auto-secure-input") == false, "the file was read")
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
  }

  @Test func aRefusedLineIsNamedByItsLineInTheTextOffered() throws {
    let diagnostics = try libghosttyDiagnostics("cursor-style = bar\nnot-a-key = 1")
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.contains(".conf:2:") == true, "\(diagnostics)")
  }

  @Test func aLineLibghosttyRefusesCostsThatLineAndNotTheRest() throws {
    let loaded = try #require(
      GhosttyLoadedConfig.load("not-a-key = 1\nmacos-auto-secure-input = false\ntheme = no-such"))
    defer { loaded.free() }
    #expect(!loaded.diagnostics.isEmpty)
    #expect(loaded.flag("macos-auto-secure-input") == false, "the good line still took")
  }

  @Test func aKeyLibghosttyDoesNotHaveIsNoFlag() throws {
    let loaded = try #require(GhosttyLoadedConfig.defaults())
    defer { loaded.free() }
    #expect(loaded.flag("not-a-key") == nil)
    #expect(loaded.flag("macos-auto-secure-input") == true, "an unset key is its default")
  }
}

import Foundation
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyRuntimeTests {
  /// libghostty names a bad line and keeps the rest, as Ghostty does, so a
  /// user's file costs only the lines it refuses, even one naming no line.
  @Test func aUsersFileWithABadLineStillAppliesItsOtherLines() {
    let runtime = GhosttyRuntime()
    runtime.apply(base: "font-not-a-real-key = 3\ntheme = no-such\nmacos-auto-secure-input = false")
    #expect(!runtime.secureInput.followsPasswordPrompts)
  }

  @Test func secureInputFollowsPasswordPromptsUnlessTheUsersFileSaysNot() {
    let runtime = GhosttyRuntime()
    #expect(runtime.secureInput.followsPasswordPrompts)
    runtime.apply(base: "macos-auto-secure-input = false")
    #expect(!runtime.secureInput.followsPasswordPrompts)
    runtime.apply(base: "")
    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func aBaseThatCouldNotBeLoadedIsTriedAgainOnTheNextApply() throws {
    let directory = ScratchDirectory.path("ghostty-runtime-config")
    defer { ScratchDirectory.remove(directory) }
    try #require(FileManager.default.createFile(atPath: directory.path, contents: nil))
    let runtime = GhosttyRuntime(configDirectory: directory)

    runtime.apply(base: "macos-auto-secure-input = false")
    #expect(runtime.secureInput.followsPasswordPrompts, "a file stood where the config goes")
    try FileManager.default.removeItem(at: directory)
    runtime.apply(base: "macos-auto-secure-input = false")

    #expect(!runtime.secureInput.followsPasswordPrompts)
  }

  @Test func aRuntimeStartsWithItsBaseAndAppLayerAlreadyRunning() {
    #expect(
      !GhosttyRuntime(base: "macos-auto-secure-input = false").secureInput.followsPasswordPrompts)
    let runtime = GhosttyRuntime(
      base: "macos-auto-secure-input = false",
      appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") })
    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func anAppLayerThatCouldNotBeLoadedAtStartIsKeptForTheRetry() throws {
    let directory = ScratchDirectory.path("ghostty-runtime-config")
    defer { ScratchDirectory.remove(directory) }
    try #require(FileManager.default.createFile(atPath: directory.path, contents: nil))
    let runtime = GhosttyRuntime(
      appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") },
      configDirectory: directory)
    try FileManager.default.removeItem(at: directory)

    runtime.apply(base: "macos-auto-secure-input = false")

    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func theAppLayerWinsOverABaseAppliedAfterIt() {
    let runtime = GhosttyRuntime()
    runtime.apply(appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") })

    runtime.apply(base: "macos-auto-secure-input = false")

    #expect(runtime.secureInput.followsPasswordPrompts)
  }
}

import AppKit
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyRuntimeTests {
  @Test func secureInputFollowsPasswordPromptsUnlessTheUsersFileSaysNot() {
    let runtime = GhosttyRuntime()
    #expect(runtime.secureInput.followsPasswordPrompts)
    runtime.apply(base: "macos-auto-secure-input = false")
    #expect(!runtime.secureInput.followsPasswordPrompts)
    runtime.apply(base: "")
    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func aBaseThatCouldNotBeLoadedIsTriedAgainOnTheNextApply() throws {
    let directory = Scratch.path("ghostty-runtime-config")
    defer { Scratch.remove(directory) }
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
      !GhosttyRuntime(readBase: { "macos-auto-secure-input = false" }).secureInput
        .followsPasswordPrompts
    )
    let runtime = GhosttyRuntime(
      readBase: { "macos-auto-secure-input = false" },
      appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") },
    )
    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func anAppLayerThatCouldNotBeLoadedAtStartIsKeptForTheRetry() throws {
    let directory = Scratch.path("ghostty-runtime-config")
    defer { Scratch.remove(directory) }
    try #require(FileManager.default.createFile(atPath: directory.path, contents: nil))
    let runtime = GhosttyRuntime(
      appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") },
      configDirectory: directory,
    )
    try FileManager.default.removeItem(at: directory)

    runtime.apply(base: "macos-auto-secure-input = false")

    #expect(runtime.secureInput.followsPasswordPrompts)
  }

  @Test func comingBackToTheAppReloadsTheUsersBase() {
    let userFile = Recorder<String>()
    let runtime = GhosttyRuntime(readBase: { userFile.received.last ?? "" })
    userFile.record("macos-auto-secure-input = false")

    NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)

    #expect(!runtime.secureInput.followsPasswordPrompts)
  }

  @Test func theAppLayerWinsOverABaseAppliedAfterIt() {
    let runtime = GhosttyRuntime()
    runtime.apply(appLayer: GhosttyConfigText { $0.set("macos-auto-secure-input", "true") })

    runtime.apply(base: "macos-auto-secure-input = false")

    #expect(runtime.secureInput.followsPasswordPrompts)
  }
}

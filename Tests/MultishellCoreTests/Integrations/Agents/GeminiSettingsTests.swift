import Foundation
import TestScratch
import Testing

@testable import MultishellCore

struct GeminiSettingsTests {
  private struct Files {
    let root = Scratch.path("gemini-settings")
    var home: URL { root.appendingPathComponent("home") }
    var workspace: URL { root.appendingPathComponent("repo") }
    var system: URL { root.appendingPathComponent("system/settings.json") }
    var defaults: URL { root.appendingPathComponent("system/system-defaults.json") }
    var environment: [String: String] {
      ["GEMINI_CLI_HOME": home.path, "GEMINI_CLI_SYSTEM_SETTINGS_PATH": system.path]
    }

    func write(_ text: String, to file: URL) throws {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try text.write(to: file, atomically: true, encoding: .utf8)
    }

    func user(_ text: String) throws {
      try write(text, to: home.appendingPathComponent(".gemini/settings.json"))
    }

    func project(_ text: String) throws {
      try write(text, to: workspace.appendingPathComponent(".gemini/settings.json"))
    }

    func trust(_ rules: [String: String]) throws {
      let json = try JSONSerialization.data(withJSONObject: rules)
      try write(
        String(decoding: json, as: UTF8.self),
        to: home.appendingPathComponent(
          ".gemini/trustedFolders.json"))
    }

    var wakes: Bool {
      GeminiSettings.wakesForBackgroundShells(environment: environment, workspace: workspace.path)
    }
  }

  private let steering = #"{"experimental":{"modelSteering":true}}"#
  private let injecting = #"{"tools":{"shell":{"backgroundCompletionBehavior":"inject"}}}"#

  @Test func withNoSettingsAShellsEndWakesNothing() {
    let files = Files()
    #expect(!files.wakes)
  }

  @Test func steeringAndAnInjectingOrNotifyingShellBothAreNeeded() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(steering)
    #expect(!files.wakes, "a shell's end is silent by default")
    try files.user(
      #"{"experimental":{"modelSteering":true},"#
        + #""tools":{"shell":{"backgroundCompletionBehavior":"notify"}}}"#)
    #expect(files.wakes)
  }

  @Test func theProjectFillsWhatTheUserLeftAndTheSystemFileHasTheLastWord() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(steering)
    try files.project(injecting)
    try files.trust([files.workspace.path: "TRUST_FOLDER"])
    #expect(files.wakes)
    try files.write(#"{"experimental":{"modelSteering":false}}"#, to: files.system)
    #expect(!files.wakes)
  }

  @Test func anUntrustedProjectsSettingsAreNotReadAsGeminiDoesNot() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(steering)
    try files.project(injecting)
    #expect(!files.wakes, "no rule names it")
    try files.trust([files.workspace.deletingLastPathComponent().path: "DO_NOT_TRUST"])
    #expect(!files.wakes)
  }

  @Test func theLongestRuleDecidesAndTrustParentCoversTheRulesParent() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(steering)
    try files.project(injecting)
    let sibling = files.root.appendingPathComponent("o").path
    try files.trust([sibling: "TRUST_PARENT"])
    #expect(files.wakes, "the parent both share")
    try files.trust([sibling: "TRUST_PARENT", files.workspace.path: "DO_NOT_TRUST"])
    #expect(!files.wakes)
  }

  @Test func withFolderTrustOffEveryProjectIsTrusted() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(
      #"{"experimental":{"modelSteering":true},"security":{"folderTrust":{"enabled":false}}}"#)
    try files.project(injecting)
    #expect(files.wakes)
  }

  @Test func theSystemDefaultsBesideTheSystemFileAreTheFirstLayer() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.write(steering, to: files.defaults)
    try files.user(injecting)
    #expect(files.wakes)
    try files.user(
      #"{"experimental":{"modelSteering":false},"#
        + #""tools":{"shell":{"backgroundCompletionBehavior":"inject"}}}"#)
    #expect(!files.wakes, "the user's own file outranks the defaults")
  }

  @Test func commentsAreReadPastAndASlashInsideAStringIsKept() throws {
    let files = Files()
    defer { try? FileManager.default.removeItem(at: files.root) }
    try files.user(
      """
      {
        // Steering lets a finished shell start a turn.
        "experimental": { "modelSteering": true }, /* and this */
        "context": { "fileName": "http://example.com//x" },
        "tools": { "shell": { "backgroundCompletionBehavior": "inject" } }
      }
      """)
    #expect(files.wakes)
  }
}

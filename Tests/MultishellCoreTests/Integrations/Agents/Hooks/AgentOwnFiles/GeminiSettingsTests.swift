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

    var wakes: Bool {
      GeminiSettings.wakesForBackgroundShells(environment: environment, directory: workspace.path)
    }

    func write(_ text: String, to file: URL) throws {
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
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
          ".gemini/trustedFolders.json"
        ),
      )
    }
  }

  private let steering = #"{"experimental":{"modelSteering":true}}"#
  private let injecting = #"{"tools":{"shell":{"backgroundCompletionBehavior":"inject"}}}"#

  @Test(arguments: ["TMPDIR", "TMP", "TEMP"])
  func anEmptyHomeReadsTheUserSettingsUnderTheTemporaryDirectory(variable: String) throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    let temporary = files.root.appendingPathComponent("temporary")
    try files.write(
      #"{"experimental":{"modelSteering":true},"#
        + #""tools":{"shell":{"backgroundCompletionBehavior":"inject"}}}"#,
      to: temporary.appendingPathComponent(".gemini/settings.json"),
    )
    let environment = [
      "HOME": "", variable: temporary.path + "/",
      "GEMINI_CLI_SYSTEM_SETTINGS_PATH": files.system.path,
    ]

    #expect(
      GeminiSettings.wakesForBackgroundShells(
        environment: environment,
        directory: files.workspace.path,
      )
    )
  }

  @Test func withNoSettingsAShellsEndWakesNothing() {
    let files = Files()
    #expect(!files.wakes)
  }

  @Test func steeringAndAnInjectingOrNotifyingShellBothAreNeeded() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    #expect(!files.wakes, "a shell's end is silent by default")
    for behavior in ["notify", "inject"] {
      try files.user(
        #"{"experimental":{"modelSteering":true},"#
          + #""tools":{"shell":{"backgroundCompletionBehavior":"\#(behavior)"}}}"#
      )
      #expect(files.wakes, "\(behavior)")
      try files.user(#"{"tools":{"shell":{"backgroundCompletionBehavior":"\#(behavior)"}}}"#)
      #expect(!files.wakes, "\(behavior) without steering")
    }
  }

  @Test func theProjectFillsWhatTheUserLeftAndTheSystemFileHasTheLastWord() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    try files.trust([files.workspace.path: "TRUST_FOLDER"])
    #expect(files.wakes)
    try files.write(#"{"experimental":{"modelSteering":false}}"#, to: files.system)
    #expect(!files.wakes)
  }

  @Test func anUntrustedProjectsSettingsAreNotReadAsGeminiDoesNot() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    #expect(!files.wakes, "no rule names it")
    try files.trust([files.workspace.deletingLastPathComponent().path: "DO_NOT_TRUST"])
    #expect(!files.wakes)
  }

  @Test func theLongestRuleDecidesAndTrustParentCoversTheRulesParent() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    let sibling = files.root.appendingPathComponent("o").path
    try files.trust([sibling: "TRUST_PARENT"])
    #expect(files.wakes, "the parent both share")
    try files.trust([sibling: "TRUST_PARENT", files.workspace.path: "DO_NOT_TRUST"])
    #expect(!files.wakes)
  }

  @Test func aRuleWhoseNameStartsTheFoldersNameDoesNotCoverIt() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    try files.trust([String(files.workspace.path.dropLast()): "TRUST_FOLDER"])
    #expect(!files.wakes)
  }

  @Test func withFolderTrustOffEveryProjectIsTrusted() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(
      #"{"experimental":{"modelSteering":true},"security":{"folderTrust":{"enabled":false}}}"#
    )
    try files.project(injecting)
    #expect(files.wakes)
  }

  @Test(arguments: [
    ["GEMINI_RESTRICTED_MODE": "true"],
    ["GEMINI_CLI_TRUST_WORKSPACE": "false"],
    ["GEMINI_RESTRICTED_MODE": "true", "GEMINI_CLI_TRUST_WORKSPACE": "true"],
  ])
  func anEnvironmentRefusingTrustOutranksEveryRule(refusal: [String: String]) throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    try files.trust([files.workspace.path: "TRUST_FOLDER"])

    let wakes = GeminiSettings.wakesForBackgroundShells(
      environment: files.environment.merging(refusal) { _, refused in refused },
      directory: files.workspace.path,
    )

    #expect(!wakes)
  }

  @Test func theLongestRuleIsCountedInUTF16UnitsAsGeminiCountsIt() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    let wide = files.root.appendingPathComponent("😀😀😀😀").path
    try files.trust([wide: "TRUST_PARENT", files.workspace.path: "DO_NOT_TRUST"])

    #expect(files.wakes, "four emoji are eight units, longer than repo's four")
  }

  @Test func ofTwoRulesTheSameLengthTheFirstInTheFileDecides() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    let sibling = files.root.appendingPathComponent("abcd").path
    let rules = #"{"\#(sibling)": "TRUST_PARENT", "\#(files.workspace.path)": "DO_NOT_TRUST"}"#
    try files.write(rules, to: files.home.appendingPathComponent(".gemini/trustedFolders.json"))

    #expect(files.wakes)
  }

  @Test func twoSpellingsOfOneFolderAreOneRuleTheLaterValueWinning() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    let folder = files.workspace.path
    let rules = #"{"\#(folder)/": "DO_NOT_TRUST", "\#(folder)": "TRUST_FOLDER"}"#
    try files.write(rules, to: files.home.appendingPathComponent(".gemini/trustedFolders.json"))

    #expect(files.wakes)
  }

  @Test func anEmptyTrustedFoldersPathFallsBackToTheDefaultAsGeminiDoes() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(steering)
    try files.project(injecting)
    try files.trust([files.workspace.path: "TRUST_FOLDER"])
    var environment = files.environment
    environment["GEMINI_CLI_TRUSTED_FOLDERS_PATH"] = ""

    let wakes = GeminiSettings.wakesForBackgroundShells(
      environment: environment,
      directory: files.workspace.path,
    )

    #expect(wakes)
  }

  @Test func anEmptySystemDefaultsPathFallsBackToTheDefaultAsGeminiDoes() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.write(steering, to: files.defaults)
    try files.user(injecting)
    var environment = files.environment
    environment["GEMINI_CLI_SYSTEM_DEFAULTS_PATH"] = ""

    let wakes = GeminiSettings.wakesForBackgroundShells(
      environment: environment,
      directory: files.workspace.path,
    )

    #expect(wakes)
  }

  @Test func theSystemDefaultsBesideTheSystemFileAreTheFirstLayer() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.write(steering, to: files.defaults)
    try files.user(injecting)
    #expect(files.wakes)
    try files.user(
      #"{"experimental":{"modelSteering":false},"#
        + #""tools":{"shell":{"backgroundCompletionBehavior":"inject"}}}"#
    )
    #expect(!files.wakes, "the user's own file outranks the defaults")
  }

  @Test func commentsAreReadPastAndASlashInsideAStringIsKept() throws {
    let files = Files()
    defer { Scratch.remove(files.root) }
    try files.user(
      """
      {
        // Steering lets a finished shell start a turn.
        "experimental": { "modelSteering": true }, /* and this */
        "context": { "fileName": "http://example.com//x" },
        "tools": { "shell": { "backgroundCompletionBehavior": "inject" } }
      }
      """
    )
    #expect(files.wakes)
  }
}

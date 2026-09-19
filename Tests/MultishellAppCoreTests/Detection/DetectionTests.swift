import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct ShellDetectionTests {
  @Test func shellsComeFromTheSystemListAndThePathWithoutDuplicates() throws {
    // Only `/bin/sh` is assumed to exist: the Linux CI image has no zsh.
    let bin = try fakeBin(["fish", "zsh", "nu", "bash"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let list = bin.appendingPathComponent("shells")
    try """
    # List of acceptable shells for chpass(1).

    /bin/sh
    \(bin.appendingPathComponent("bash").path)
    \(bin.appendingPathComponent("zsh").path)
    /no/such/shell
    """.write(to: list, atomically: true, encoding: .utf8)

    let detection = ShellDetection(path: bin.path, systemList: list, loginShell: "/bin/sh")

    #expect(
      detection.installed == [
        bin.appendingPathComponent("bash").path, bin.appendingPathComponent("fish").path,
        bin.appendingPathComponent("nu").path, "/bin/sh", bin.appendingPathComponent("zsh").path,
      ], "sorted by name then path, listed once, the missing one dropped")
    #expect(detection.isInstalled("/bin/sh"))
    #expect(detection.isInstalled(ShellCatalogue.loginShellID))
    #expect(!detection.isInstalled("/opt/gone/fish"))
  }

  @Test func theDropdownLeadsWithTheLoginShellAndKeepsAStaleChoice() {
    let detection = ShellDetection(installed: ["/bin/bash", "/bin/zsh"], loginShell: "/bin/zsh")

    let plain = detection.options(selected: nil)
    #expect(plain.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "custom"])
    #expect(plain[0].label == "Login shell (/bin/zsh)")
    #expect(plain[1].label == "bash  /bin/bash")
    #expect(plain.last?.label == "Custom path…")

    let stale = detection.options(selected: "/opt/homebrew/bin/fish")
    #expect(
      stale.map(\.id) == ["login", "/bin/bash", "/bin/zsh", "/opt/homebrew/bin/fish", "custom"])
    #expect(stale[3].label == "fish  /opt/homebrew/bin/fish (not installed)")
    #expect(stale[3].isInstalled == false)
    #expect(detection.options(selected: "/bin/bash").count == 4, "an installed choice adds nothing")
    #expect(detection.options(selected: "custom").count == 4, "and neither does the custom path")
    #expect(detection.isInstalled(ShellCatalogue.customID))
  }

  /// Every other row is checked against the disk. `$SHELL` pointing at an
  /// uninstalled fish showed an unmarked row, and each new tab died silently.
  @Test func aLoginShellThatIsNotThereIsMarkedLikeAnyOtherMissingOne() {
    let gone = ShellDetection(installed: ["/bin/zsh"], loginShell: "/opt/gone/fish")
    #expect(!gone.isInstalled(ShellCatalogue.loginShellID))
    #expect(gone.options(selected: nil)[0].isInstalled == false)

    let there = ShellDetection(installed: ["/bin/zsh"], loginShell: "/bin/sh")
    #expect(there.isInstalled(ShellCatalogue.loginShellID))
    #expect(there.options(selected: nil)[0].isInstalled)
  }

  @Test func aMissingSystemListIsNotAnError() {
    let detection = ShellDetection(
      path: "/nowhere", systemList: URL(fileURLWithPath: "/no/such/shells"), loginShell: "/bin/sh")
    #expect(detection.installed.isEmpty)
    #expect(detection.options(selected: nil).map(\.id) == ["login", "custom"])
  }
}

@Suite
struct EditorDetectionTests {
  @Test func editorsAreFoundByBundleIdOrByShimAndTerminalOnesByShimOnly() throws {
    let bin = try fakeBin(["code", "nvim"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let apps = ["dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app")]

    let detection = EditorDetection(path: bin.path) { apps[$0] }

    #expect(Set(detection.found.keys) == ["vscode", "zed", "nvim"])
    #expect(detection.found["zed"]?.application?.path == "/Applications/Zed.app")
    #expect(detection.found["zed"]?.command == nil)
    #expect(detection.found["vscode"]?.application == nil, "found through its shim only")
    #expect(detection.found["vscode"]?.command?.path == bin.appendingPathComponent("code").path)
    #expect(detection.found["nvim"]?.command?.path == bin.appendingPathComponent("nvim").path)
    #expect(detection.isInstalled("custom") && !detection.isInstalled("cursor"))
  }

  @Test func theDropdownListsInstalledEditorsTheStaleChoiceAndCustom() {
    let detection = EditorDetection(found: [
      "zed": .init(application: URL(fileURLWithPath: "/Applications/Zed.app"), command: nil)
    ])
    #expect(detection.options(selected: nil).map(\.id) == ["none", "zed", "custom"])

    let stale = detection.options(selected: "vscode")
    #expect(stale.map(\.id) == ["none", "vscode", "zed", "custom"], "catalogue order")
    #expect(stale[1].label == "Visual Studio Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-editor")
    #expect(unknown.map(\.id).contains("future-editor"), "a newer build's id still shows")
  }

  @Test func theAgentAndEditorDropdownsShareOneShape() {
    let agents = AgentDetection(found: [:]).options(selected: "custom")
    let editors = EditorDetection(found: [:]).options(selected: "custom")
    #expect(agents == editors, "nothing installed and Custom chosen: identical rows")
    #expect(agents.map(\.id) == ["none", "custom"], "a chosen Custom adds no stale row")
    #expect(agents.last?.label == "Custom command…")
    #expect(
      AgentDetection(found: [:]).options(selected: "none").map(\.id) == ["none", "custom"],
      "and neither does a chosen None")
  }
}

@Suite
struct AgentDetectionTests {
  @Test func agentsAreFoundOnTheGivenPathOnly() throws {
    let bin = try fakeBin(["claude", "aider"])
    defer { try? FileManager.default.removeItem(at: bin) }

    let detection = AgentDetection(path: "/usr/bin:\(bin.path)")
    #expect(Set(detection.found.keys) == ["claude", "aider"])
    #expect(detection.found["claude"]?.path == bin.appendingPathComponent("claude").path)
    #expect(detection.isInstalled("claude"))
    #expect(!detection.isInstalled("codex"))
    #expect(AgentDetection(path: "/usr/bin").found.isEmpty, "nothing on a path with no agents")
  }

  @Test func theDropdownListsInstalledAgentsTheStaleChoiceAndCustom() throws {
    let bin = try fakeBin(["codex"])
    defer { try? FileManager.default.removeItem(at: bin) }
    let detection = AgentDetection(path: bin.path)

    let plain = detection.options(selected: nil).map(\.id)
    #expect(plain == ["none", "codex", "custom"])

    let stale = detection.options(selected: "claude")
    #expect(stale.map(\.id) == ["none", "claude", "codex", "custom"], "catalogue order")
    #expect(stale[1].label == "Claude Code (not installed)")
    #expect(!stale[1].isInstalled)

    let unknown = detection.options(selected: "future-agent")
    #expect(unknown.map(\.id).contains("future-agent"), "a newer build's id still shows")
    #expect(detection.isInstalled("custom"))
    #expect(!detection.isInstalled("claude"))
  }
}

/// The terminal font picker's rows.
@Suite
struct FontDetectionTests {
  private let fonts = FontDetection(
    monospaced: ["Menlo", "JetBrains Mono"], others: ["Helvetica", "Avenir"])

  @Test func systemFirstThenMonospacedThenADividerThenTheRestSorted() {
    let ids = fonts.options(selected: nil).map(\.id)
    #expect(
      ids == [
        FontDetection.systemID, "JetBrains Mono", "Menlo", FontDetection.dividerID, "Avenir",
        "Helvetica",
      ])
    #expect(fonts.options(selected: nil)[0].label == "System monospace")
  }

  @Test func aStoredFontTheMachineLacksIsListedMarkedRatherThanDropped() {
    let options = fonts.options(selected: "Fira Code")
    let missing = options.first { $0.id == "Fira Code" }
    #expect(missing?.label == "Fira Code (not installed)" && missing?.isInstalled == false)
    #expect(fonts.options(selected: "Menlo").allSatisfy { $0.isInstalled })
    #expect(fonts.options(selected: FontDetection.systemID).allSatisfy { $0.isInstalled })
  }

  @Test func withNoOtherFamiliesThereIsNoDivider() {
    let only = FontDetection(monospaced: ["Menlo"], others: [])
    #expect(!only.options(selected: nil).map(\.id).contains(FontDetection.dividerID))
  }
}

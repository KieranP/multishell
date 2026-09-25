import Foundation
import Testing

@testable import MultishellAppCore

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

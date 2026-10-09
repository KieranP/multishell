import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct EditorDetectionTests {
  @Test func editorsAreFoundByBundleIdOrByShimAndTerminalOnesByShimOnly() throws {
    let bin = try fakeBin(["code", "nvim"])
    defer { Scratch.remove(bin) }
    let apps = ["dev.zed.Zed": URL(fileURLWithPath: "/Applications/Zed.app")]

    let detection = EditorDetection(searchPath: bin.path) { apps[$0] }

    #expect(Set(detection.found.keys) == ["vscode", "zed", "nvim"])
    #expect(detection.found["zed"]?.application?.path == "/Applications/Zed.app")
    #expect(detection.found["zed"]?.executable == nil)
    #expect(detection.found["vscode"]?.application == nil, "found through its shim only")
    #expect(detection.found["vscode"]?.executable?.path == bin.appendingPathComponent("code").path)
    #expect(detection.found["nvim"]?.executable?.path == bin.appendingPathComponent("nvim").path)
    #expect(detection.found["cursor"] == nil)
  }

  @Test func theDropdownListsInstalledEditorsTheStaleChoiceAndCustom() {
    let detection = EditorDetection(found: [
      "zed": .init(application: URL(fileURLWithPath: "/Applications/Zed.app"), executable: nil)
    ])
    #expect(detection.options(selected: nil).map(\.id) == ["none", "zed", "custom"])

    let stale = detection.options(selected: "vscode")
    #expect(stale.map(\.id) == ["none", "vscode", "zed", "custom"], "catalogue order")
    #expect(stale[1].label == "Visual Studio Code (not installed)")

    let unknown = detection.options(selected: "future-editor")
    #expect(unknown.map(\.id).contains("future-editor"), "a newer build's id still shows")
  }
}

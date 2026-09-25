import Testing

@testable import MultishellAppCore

@Suite
struct DetectionOptionTests {
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

import Testing

@testable import MultishellAppCore

@Suite
struct ArrayDetectionOptionLabelTests {
  @Test func anOptionIsNamedByItsIdAndADividerOrAStrangerByNothing() {
    let options = [
      DetectionOption(id: "zsh", label: "zsh"),
      DetectionOption(id: DetectionOption.dividerID, label: ""),
    ]

    #expect(options.label(of: "zsh") == "zsh")
    #expect(options.label(of: DetectionOption.dividerID) == nil)
    #expect(options.label(of: "fish") == nil)
  }
}

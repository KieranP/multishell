import Testing

@testable import MultishellAppCore

@Suite
struct IgnoreVerdictsTests {
  @Test func gitIsAskedAboutTheShallowestDirectoryItHasNotAnswered() {
    var verdicts = IgnoreVerdicts()
    #expect(verdicts.unasked(on: ["node_modules/a/b", "src/deep"]) == ["node_modules", "src"])

    verdicts.record(asked: ["node_modules", "src"], ignored: ["node_modules"])

    #expect(verdicts.unasked(on: ["node_modules/a/b", "src/deep"]) == ["src/deep"])
  }

  @Test func aPathIsIgnoredWhereAnyDirectoryOnItsWayIs() {
    var verdicts = IgnoreVerdicts()
    verdicts.record(asked: ["node_modules", "src"], ignored: ["node_modules"])
    verdicts.record(asked: ["src/deep"], ignored: [])

    #expect(verdicts.isIgnored("node_modules/a/b") == true)
    #expect(verdicts.isIgnored("src/deep") == false)
    #expect(verdicts.isIgnored("src/other") == nil, "not asked yet")
  }
}

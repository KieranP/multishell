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

  @Test func forgettingBelowSomePathsKeepsTheirOwnAnswersAndTheirSiblings() {
    var verdicts = IgnoreVerdicts()
    verdicts.record(asked: ["a", "b", "c", "ab"], ignored: [])
    verdicts.record(asked: ["a/x", "b/y", "c/z", "ab/w"], ignored: [])
    verdicts.record(asked: ["a/x/deep"], ignored: [])

    verdicts.forget(below: ["a", "b/y"])

    #expect(verdicts.isIgnored("a") == false)
    #expect(verdicts.isIgnored("a/x") == nil)
    #expect(verdicts.isIgnored("a/x/deep") == nil)
    #expect(verdicts.isIgnored("b/y") == false)
    #expect(verdicts.isIgnored("c/z") == false)
    #expect(verdicts.isIgnored("ab/w") == false)
  }

  @Test func eachUnaskedDirectoryIsListedOnceInTheOrderFirstMet() {
    let verdicts = IgnoreVerdicts()

    #expect(verdicts.unasked(on: ["b/1", "a/2", "b/3", "a/4"]) == ["b", "a"])
  }
}

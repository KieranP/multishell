import Testing

@testable import MultishellAppCore

@Suite
struct HighlightCaptureRolesTests {
  @Test func aCaptureTakesItsFirstComponentsRoleButForTheExceptions() {
    #expect(HighlightCaptureRoles.role(forCapture: "keyword.function", in: .swift) == .keyword)
    #expect(HighlightCaptureRoles.role(forCapture: "constructor", in: .swift) == .keyword)
    #expect(HighlightCaptureRoles.role(forCapture: "variable.builtin", in: .swift) == .keyword)
    #expect(HighlightCaptureRoles.role(forCapture: "string.escape", in: .swift) == .string)
    #expect(HighlightCaptureRoles.role(forCapture: "constant.builtin", in: .swift) == .number)
    #expect(
      HighlightCaptureRoles.role(forCapture: "punctuation.bracket", in: .swift) == .punctuation
    )
    #expect(HighlightCaptureRoles.role(forCapture: "variable.parameter", in: .swift) == .plain)
    #expect(HighlightCaptureRoles.role(forCapture: "operator", in: .swift) == .plain)
    #expect(
      HighlightCaptureRoles.role(forCapture: "character.special", in: .swift) == .plain,
      "Swift's `_`",
    )
    #expect(HighlightCaptureRoles.role(forCapture: "character", in: .zig) == .string)
    #expect(
      HighlightCaptureRoles.role(forCapture: "spell", in: .swift) == nil,
      "a spell checker's mark",
    )
    #expect(
      HighlightCaptureRoles.role(forCapture: "constructor", in: .python) == .type,
      "a class name",
    )
  }

  @Test(arguments: [
    ("conditional", HighlightRole.keyword), ("repeat", .keyword), ("exception", .keyword),
    ("include", .keyword), ("storageclass", .keyword), ("tag", .keyword), ("float", .number),
    ("namespace", .type),
  ])
  func theOlderNamesSomeGrammarsUseTakeTheirRoles(capture: String, role: HighlightRole) {
    #expect(HighlightCaptureRoles.role(forCapture: capture, in: .kotlin) == role)
  }
}

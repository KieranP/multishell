import Testing

@testable import MultishellHighlight

@Suite
struct InjectableAttributeCandidatesTests {
  private static func candidates(in text: String) -> [String] {
    let units = Array(text.utf16)
    return InjectableAttributeCandidates.candidates(in: units).map { candidate in
      String(decoding: units[candidate.range], as: UTF16.self)
    }
  }

  @Test func aStyleOrOnNameWithAValueIsFound() {
    let text = "<p style=\"a\" ONCLICK = 'b' class=\"c\" onkeydown=d>x</p>"

    #expect(Self.candidates(in: text) == ["style", "ONCLICK", "onkeydown"])
  }

  @Test func aNameCarriesItsKindInAnyCase() {
    let units = Array("<p STYLE=a onClick=b>".utf16)

    #expect(InjectableAttributeCandidates.candidates(in: units).map(\.kind) == [.style, .handler])
  }

  @Test(arguments: ["<div {...rest}onclick=\"go()\">", "<p\u{0C}onclick=go()>"])
  func aNameAfterAnyUnitThatEndsANameIsFound(text: String) {
    #expect(Self.candidates(in: text) == ["onclick"])
  }

  @Test(arguments: [
    "<p class=\"x\" id=y>", "<p on:click={go}>", "<p data-style=\"x\">", "<p one=\"x\">",
    "<p onfoo=x>", "<p styles=\"x\">", "<p xonclick=\"x\">",
  ])
  func anotherNameIsNotFound(text: String) {
    #expect(Self.candidates(in: text).isEmpty)
  }

  @Test func aBareNameIsFoundSoItOutranksARepeat() {
    let text = "<p onclick style ONCLICK=\"go()\">"

    #expect(Self.candidates(in: text) == ["onclick", "style", "ONCLICK"])
  }
}

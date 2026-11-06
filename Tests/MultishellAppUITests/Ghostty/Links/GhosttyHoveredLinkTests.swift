import Foundation
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyHoveredLinkTests {
  private func isLink(_ word: String, in line: String) -> Bool {
    let column = line.distance(from: line.startIndex, to: line.range(of: word)!.lowerBound)
    return GhosttyHoveredLink.link(word: word, startingAt: column, in: line) != nil
  }

  @Test func theLinkIsItsWholeTokenWithoutTrailingPunctuation() {
    let address = GhosttyHoveredLink.link(
      word: "https",
      startingAt: 6,
      in: "  see https://x.com/a, then",
    )
    let path = GhosttyHoveredLink.link(
      word: "Sources/App/Model.swift",
      startingAt: 9,
      in: "⏺ Update(Sources/App/Model.swift:12)",
    )

    #expect(address == "https://x.com/a")
    #expect(path == "Sources/App/Model.swift:12")
  }

  @Test func aWebAddressIsALinkFromItsSchemeToItsEnd() {
    let line = "  see https://github.com/acme/app/pull/12 for more"
    #expect(isLink("https", in: line))
    #expect(isLink("//github.com/acme/app/pull/12", in: line))
  }

  @Test func aPathWithALineNumberIsALink() {
    #expect(isLink("Sources/App/Model.swift", in: "⏺ Update(Sources/App/Model.swift:12)"))
    #expect(isLink("./build.sh", in: "run ./build.sh first"))
    #expect(isLink("~/notes.md", in: "wrote ~/notes.md."))
  }

  @Test func aBareFileNameIsALink() {
    #expect(isLink("README.md", in: "Read README.md, then"))
    #expect(isLink("AppModel.swift", in: "  AppModel.swift  +12 -3"))
  }

  @Test func proseIsNoLink() {
    #expect(!isLink("changed", in: "I changed three files."))
    #expect(!isLink("e.g", in: "a tool, e.g. ripgrep"))
    #expect(!isLink("1.2.3", in: "version 1.2.3 is out"))
    #expect(!isLink("12", in: "12 tests passed"))
  }

  @Test func aGapOrBracketBesideALinkIsNoLink() {
    #expect(!isLink("  ", in: "  Sources/App/Model.swift  +12 -3"))
    #expect(!isLink("(", in: "⏺ Update(Sources/App/Model.swift)"))
    #expect(!isLink(")", in: "⏺ Update(Sources/App/Model.swift)"))
  }

  @Test func memberAccessInCodeIsNoFileName() {
    #expect(!isLink("self.window", in: "    self.window = nil"))
    #expect(!isLink("user.id", in: "  let id = user.id"))
  }

  @Test func aBareFileNamesLineNumberIsLeftOffSoTheClickedLinkRuleTakesIt() {
    let link = GhosttyHoveredLink.link(
      word: "AppModel.swift",
      startingAt: 7,
      in: "Edited AppModel.swift:42",
    )

    #expect(link == "AppModel.swift")
    #expect(URL(string: link ?? "")?.scheme == nil, "a scheme sends the rule past its paths")
  }

  @Test func sourceFilesMacOSHasNoTypeForAreFileNames() {
    for name in ["main.rs", "main.go", "Cargo.lock", "App.jsx", "Page.svelte", "Main.kt"] {
      #expect(isLink(name, in: "Edited \(name) ok"), "\(name)")
    }
  }

  @Test func anApplicationsExtensionIsNoFileName() {
    #expect(!isLink("Keynote.app", in: "open Keynote.app now"))
  }

  @Test func theOccurrenceNearestTheColumnIsJudged() {
    let line = "main.swift main"
    #expect(GhosttyHoveredLink.link(word: "main", startingAt: 11, in: line) == nil)
    #expect(GhosttyHoveredLink.link(word: "main", startingAt: 0, in: line) == "main.swift")
  }

  @Test func aWordMissingFromTheLineIsJudgedAlone() {
    #expect(
      GhosttyHoveredLink.link(word: "Package.swift", startingAt: 3, in: "elsewhere")
        == "Package.swift"
    )
    #expect(GhosttyHoveredLink.link(word: "hello", startingAt: 3, in: "elsewhere") == nil)
  }
}

import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct EnvironmentDumpParserTests {
  @Test func nulSeparatedOutputParsesIncludingValuesWithNewlinesAndEquals() {
    let text = "PATH=/opt/homebrew/bin:/usr/bin\0MULTI=line one\nline two\0EQ=a=b=c\0BROKEN\0"
    let parsed = EnvironmentDumpParser.parse(nulSeparated: text)
    #expect(parsed["PATH"] == "/opt/homebrew/bin:/usr/bin")
    #expect(parsed["MULTI"] == "line one\nline two")
    #expect(parsed["EQ"] == "a=b=c")
    #expect(parsed["BROKEN"] == nil)
    #expect(parsed.count == 3)
  }

  @Test func anRcFileGreetingBeforeTheFirstEntryDoesNotBecomeAKey() {
    let text = "Welcome back!\nHave a nice day\nHOME=/Users/dev\0PATH=/bin\0"
    let parsed = EnvironmentDumpParser.parse(nulSeparated: text)
    #expect(parsed["HOME"] == "/Users/dev")
    #expect(parsed["PATH"] == "/bin")
    #expect(parsed.count == 2)
  }

  @Test func aGreetingHoldingAnEqualsSignStillLeavesTheFirstEntryItsKey() {
    let text = "==== welcome ====\nPATH=/bin\0HOME=/Users/dev\0"
    let parsed = EnvironmentDumpParser.parse(nulSeparated: text)
    #expect(parsed["PATH"] == "/bin", "the first `=` is the banner's, the key is after the newline")
    #expect(parsed["HOME"] == "/Users/dev")
    #expect(parsed.count == 2)
  }

  @Test func onlyWhatFollowsTheMarkerIsTheEnvironment() {
    let text = "motd=hi\n\(EnvironmentDumpParser.startMarker)\nHOME=/u\0PATH=/bin\0"

    #expect(EnvironmentDumpParser.parse(nulSeparated: text) == ["HOME": "/u", "PATH": "/bin"])
  }
}

import Testing

@testable import MultishellCore

@Suite
struct StringHomeAbbreviationTests {
  @Test func theHomeDirectoryAbbreviatesToWhateverTheCallerStandsItFor() {
    #expect("/Users/me/x".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me", as: "$HOME") == "$HOME")
    #expect("/Users/me/Work/x".abbreviatingHomeDirectory(home: "/Users/me") == "~/Work/x")
    #expect("/Users/me".abbreviatingHomeDirectory(home: "/Users/me") == "~")
    #expect("/Users/meg/x".abbreviatingHomeDirectory(home: "/Users/me") == "/Users/meg/x")
    #expect("/tmp/x".abbreviatingHomeDirectory(home: "/Users/me") == "/tmp/x")
  }
}

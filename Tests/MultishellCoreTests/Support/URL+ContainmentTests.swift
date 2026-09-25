import Foundation
import Testing

@testable import MultishellCore

@Suite
struct URLContainmentTests {
  @Test func aPathIsUnderABaseByWholeComponentOnly() {
    let base = URL(fileURLWithPath: "/a/b", isDirectory: true)
    #expect(URL(fileURLWithPath: "/a/b/c/d").pathComponents(under: base) == ["c", "d"])
    #expect(URL(fileURLWithPath: "/a/b").pathComponents(under: base) == [])
    #expect(URL(fileURLWithPath: "/a/bc").pathComponents(under: base) == nil)
    #expect(URL(fileURLWithPath: "/x").pathComponents(under: URL(fileURLWithPath: "/")) == ["x"])
  }
}

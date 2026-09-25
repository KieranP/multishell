import Foundation
import Testing

@testable import MultishellCore

extension ProjectTests {
  @Test func aBareRepositoryIsNamedWithoutItsSuffixOrByTheFolderThatHidesIt() {
    #expect(Project(path: URL(fileURLWithPath: "/w/demo")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo.git")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo/.bare")).name == "demo")
    #expect(Project(path: URL(fileURLWithPath: "/w/demo/.git")).name == "demo")
  }
}

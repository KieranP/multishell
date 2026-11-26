import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct FileTreeBuildingTests {
  @Test func aPathFifteenHundredFoldersDeepBuildsOnADispatchThread() async {
    let path = Array(repeating: "a", count: 1_500).joined(separator: "/")
    let roots = await runOnDispatch {
      FileTree.build([path], folders: [], repositories: [], ignored: [])
    }
    #expect(roots.count == 1)
    var depth = 0
    var level = roots
    while let node = level.first {
      depth += 1
      level = node.children
    }
    #expect(depth == 1_500)
  }
}

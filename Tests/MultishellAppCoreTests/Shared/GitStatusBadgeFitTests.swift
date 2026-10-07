import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct GitStatusBadgeFitTests {
  private func status(
    hasLineChanges: Bool, unscoredFiles: Int = 0, ahead: Int = 0
  ) -> WorktreeStatus {
    var status = WorktreeStatus()
    if hasLineChanges {
      status.changedFiles = 1
      status.insertions = 12
    }
    status.unscoredFiles = unscoredFiles
    status.ahead = ahead
    return status
  }

  @Test func aRowOutOfRoomDropsTheFileCountFirstThenTheArrows() {
    let busy = status(hasLineChanges: true, unscoredFiles: 3, ahead: 2)

    #expect(GitStatusBadgeFit.allCases.map { $0.showsFiles(of: busy) } == [true, false, false])
    #expect(GitStatusBadgeFit.allCases.map { $0.showsArrows(of: busy) } == [true, true, false])
  }

  @Test func aBadgeOfArrowsAloneKeepsThemAtItsNarrowest() {
    #expect(
      GitStatusBadgeFit.essentials.showsArrows(of: status(hasLineChanges: false, ahead: 2)))
  }
}

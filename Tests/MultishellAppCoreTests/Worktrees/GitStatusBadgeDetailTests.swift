import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct GitStatusBadgeDetailTests {
  private func status(lines: Bool, files: Int = 0, ahead: Int = 0) -> WorktreeStatus {
    var status = WorktreeStatus()
    if lines {
      status.changedFiles = 1
      status.insertions = 12
    }
    status.unscoredFiles = files
    status.ahead = ahead
    return status
  }

  @Test func aRowOutOfRoomDropsTheFileCountFirstThenTheArrows() {
    let busy = status(lines: true, files: 3, ahead: 2)

    #expect(GitStatusBadgeDetail.allCases.map { $0.showsFiles(of: busy) } == [true, false, false])
    #expect(GitStatusBadgeDetail.allCases.map { $0.showsArrows(of: busy) } == [true, true, false])
  }

  @Test func aBadgeOfArrowsAloneKeepsThemAtItsNarrowest() {
    #expect(GitStatusBadgeDetail.essentials.showsArrows(of: status(lines: false, ahead: 2)))
  }
}

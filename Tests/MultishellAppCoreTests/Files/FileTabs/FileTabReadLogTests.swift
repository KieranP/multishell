import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct FileTabReadLogTests {
  @Test func theHighlightingARereadSetOffPushesTheNextReadBackAsTheReadDoes() throws {
    var log = FileTabReadLog()
    let id = UUID()
    log.begin(id)
    _ = log.finish(id, cost: .milliseconds(10))
    let readAlone = try #require(log.nextDue(id))

    log.noteHighlightCost(.milliseconds(40), of: id)

    #expect(try #require(log.nextDue(id)) - readAlone == .milliseconds(400))
  }

  @Test func aTabShownAgainCountsOneHighlightingPerRead() throws {
    var log = FileTabReadLog()
    let id = UUID()
    log.begin(id)
    _ = log.finish(id, cost: .milliseconds(10))
    let readAlone = try #require(log.nextDue(id))

    for _ in 0..<20 { log.noteHighlightCost(.milliseconds(50), of: id) }

    #expect(try #require(log.nextDue(id)) - readAlone == .milliseconds(500))
  }
}

import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct ControlReplyJSONTests {
  private struct Unencodable: Encodable {
    func encode(to encoder: any Encoder) throws {
      throw EncodingError.invalidValue(
        self,
        .init(codingPath: [], debugDescription: "stands in for a listing that fails"),
      )
    }
  }

  @Test func aListingThatFailsToEncodeIsRefusedNotAnsweredAsDone() {
    #expect(ControlReply.json(Unencodable()) == .refused(.replyNotEncoded))
  }

  @Test func aSettingThatFailsToEncodeIsRefusedNotAnsweredAsDone() {
    #expect(ControlReply.jsonObject(Date()) == .refused(.replyNotEncoded))
  }
}

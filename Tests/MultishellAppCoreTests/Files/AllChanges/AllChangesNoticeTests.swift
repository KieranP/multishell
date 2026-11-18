import Testing

@testable import MultishellAppCore

@Suite
struct AllChangesNoticeTests {
  @Test func aFileTooLargeBinaryOrUnreadableOffersTheEditorAsItsFileTabDoes() {
    #expect(AllChangesNotice.tooLarge(bytes: 2_000_000).action == .openInEditor)
    #expect(AllChangesNotice.binary(bytes: 10_000).action == .openInEditor)
    #expect(AllChangesNotice.unreadable.action == .openInEditor)
  }

  @Test func anImageOrAFilePastTheRowCapOffersItsOwnTab() {
    #expect(AllChangesNotice.image.action == .openFile)
    #expect(AllChangesNotice.pastRowCap.action == .openFile)
  }

  @Test func aFileThatIsNowhereEmptyOrStillReadingOffersNothing() {
    #expect(AllChangesNotice.missing.action == nil)
    #expect(AllChangesNotice.empty.action == nil)
    #expect(AllChangesNotice.reading.action == nil)
  }
}

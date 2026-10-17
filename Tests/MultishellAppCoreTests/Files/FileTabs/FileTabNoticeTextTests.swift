import Testing

@testable import MultishellAppCore

@Suite
struct FileTabNoticeTextTests {
  @Test func aFileThatIsNowhereOffersNoEditorAndOneTooLargeSaysItsSize() {
    #expect(!FileTabNoticeText.offersEditor(for: .missing))
    #expect(FileTabNoticeText.offersEditor(for: .tooLarge(bytes: 2_000_000)))
    #expect(FileTabNoticeText.message(for: .tooLarge(bytes: 2_000_000))?.contains("MB") == true)
  }
}

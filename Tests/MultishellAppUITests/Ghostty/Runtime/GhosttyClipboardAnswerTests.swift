import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyClipboardAnswerTests {
  private func answer(
    _ request: GhosttyClipboardRequest,
    at location: ghostty_clipboard_e = GHOSTTY_CLIPBOARD_STANDARD,
    text: String?
  ) -> GhosttyClipboardAnswer {
    GhosttyClipboardAnswer(request, at: location, text: text)
  }

  @Test func aReadForTextGetsTheTextAndIsStarted() {
    let answer = answer(.init(handle: nil, wantsText: true), text: "hi")
    #expect(answer == .reply(text: "hi", available: []))
    #expect(answer.result == GHOSTTY_CLIPBOARD_READ_STARTED)
  }

  @Test func aReadForTextOfAnEmptyPasteboardIsAnsweredUnavailableAtOnce() {
    let answer = answer(.init(handle: nil, wantsText: true), text: nil)
    #expect(answer == .unavailable)
    #expect(answer.result == GHOSTTY_CLIPBOARD_READ_UNAVAILABLE)
  }

  @Test func aListingNamesTextWhereThereIsSomeAndHandsNoneOver() {
    let answer = answer(.init(handle: nil, wantsList: true), text: "hi")
    #expect(answer == .reply(text: nil, available: [GhosttyClipboard.textMime]))
  }

  @Test func aKittyPasteEventAskingOnlyWhatIsOnOfferIsStartedOverAnEmptyPasteboard() {
    let answer = answer(.init(handle: nil, wantsList: true), text: nil)
    #expect(answer == .reply(text: nil, available: []))
    #expect(answer.result == GHOSTTY_CLIPBOARD_READ_STARTED)
  }

  @Test func aReadForNothingAPaneServesIsAnsweredUnavailableAtOnce() {
    #expect(answer(.init(handle: nil), text: "hi") == .unavailable)
  }

  @Test func onlyTheGeneralPasteboardIsServed() {
    let answer = answer(
      .init(handle: nil, wantsText: true), at: GHOSTTY_CLIPBOARD_SELECTION, text: "hi")
    #expect(answer == .unsupported)
    #expect(answer.result == GHOSTTY_CLIPBOARD_READ_UNSUPPORTED)
  }
}

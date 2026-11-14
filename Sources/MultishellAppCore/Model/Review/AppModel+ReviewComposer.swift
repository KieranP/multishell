import Foundation
import MultishellCore

extension AppModel {
  /// A line's + in the gutter, a drag down it, or Comment on Lines, on `path`'s
  /// lines. Not over a composer holding text, which would lose what was typed.
  public func openReviewComposer(
    on selection: ReviewLineSelection,
    ofFile path: String,
    in tabID: ReviewTabID,
  ) {
    guard let worktreeID = reviewWorktree(of: tabID), !composerHoldsUnsavedShownText(in: tabID)
    else { return }
    let composer = ReviewComposer(
      path: path,
      side: selection.side,
      lines: selection.lines,
      quote: reviewQuote(of: selection.lines, on: selection.side, ofFile: path, in: tabID),
      scope: fileTabScope(in: worktreeID),
      editing: nil,
    )
    reviewComposers[tabID] = composer
    // A + on the clip's last row opens the card below it, so the view scrolls to show it.
    reviewCardRevealRequests[tabID] = .composer(composer.id)
    reviewDrafts[tabID] = ""
    reviewComposerKeyboardRequests.insert(tabID)
    // The composer takes the keyboard, so the tab is focused as a click in its text would.
    noteFileTabFocused(tabID)
  }

  /// A pending comment's Edit: its card becomes the composer, holding its text.
  public func startEditingReviewComment(_ id: ReviewComment.ID, in tabID: ReviewTabID) {
    guard let worktreeID = reviewWorktree(of: tabID), !composerHoldsUnsavedShownText(in: tabID),
      let comment = reviewComments(in: worktreeID).first(where: { $0.id == id }),
      comment.isPending
    else { return }
    let composer = ReviewComposer(
      path: comment.path,
      side: comment.side,
      lines: comment.lines,
      quote: comment.quote,
      scope: comment.scope,
      editing: id,
    )
    reviewComposers[tabID] = composer
    reviewCardRevealRequests[tabID] = .composer(composer.id)
    reviewDrafts[tabID] = comment.text
    reviewComposerKeyboardRequests.insert(tabID)
    noteFileTabFocused(tabID)
  }

  public func reviewDraft(in tabID: ReviewTabID) -> String {
    reviewDrafts[tabID] ?? ""
  }

  public func noteReviewDraft(_ text: String, in tabID: ReviewTabID) {
    reviewDrafts[tabID] = text
  }

  /// The keyboard goes back to the tab, the card's field leaving with the card.
  public func cancelReviewComposer(in tabID: ReviewTabID) {
    setIfChanged(\.reviewComposers[tabID], nil)
    reviewDrafts[tabID] = nil
    reviewComposerKeyboardRequests.remove(tabID)
    fileTabFocusRequest = tabID
  }

  /// Add comment, or Save while editing. Refused with no text or no lines
  /// read, the composer staying open.
  @discardableResult
  public func commitReviewComposer(in tabID: ReviewTabID) -> Bool {
    guard let composer = reviewComposers[tabID], let worktreeID = reviewWorktree(of: tabID),
      let text = reviewDraft(in: tabID).trimmedOfAllWhitespaceOrNil
    else { return false }
    let isEditingAPendingComment = reviewComments(in: worktreeID).contains { comment in
      comment.id == composer.editing && comment.isPending
    }
    if let editing = composer.editing, isEditingAPendingComment {
      editReviewComment(editing, in: worktreeID, text: text)
    } else {
      // A quote is what keeps the comment on its lines. An edit whose comment was
      // sent or removed meanwhile is kept as a new one, not lost.
      guard !composer.quote.isEmpty else { return false }
      var comment = ReviewComment(
        path: composer.path,
        side: composer.side,
        scope: composer.scope,
        lines: composer.lines,
        quote: composer.quote,
        text: text,
      )
      // Lines rewritten while it was typed no longer read as its quote.
      let quote = reviewQuote(
        of: composer.lines,
        on: composer.side,
        ofFile: composer.path,
        in: tabID,
      )
      if quote != composer.quote { comment.noteLinesChanged() }
      guard addReviewComment(comment, in: worktreeID) else { return false }
    }
    cancelReviewComposer(in: tabID)
    return true
  }

  /// The lines' text as the tab last read the file, empty where it holds no rows of it.
  func reviewQuote(
    of lines: ClosedRange<Int>,
    on side: DiffSide,
    ofFile path: String,
    in tabID: ReviewTabID,
  ) -> [String] {
    // Walked rather than taken from the side's whole text, which copies every line.
    (reviewRows(ofFile: path, in: tabID) ?? []).compactMap { line in
      guard side.shows(line.kind), let number = line.number(on: side), lines.contains(number)
      else { return nil }
      return line.text
    }
  }

  /// Once per opening, so a card rebuilt by a layout switch leaves the keyboard be.
  public func reviewComposerAsksForKeyboard(in tabID: ReviewTabID) -> Bool {
    reviewComposerKeyboardRequests.contains(tabID)
  }

  public func noteReviewComposerTookKeyboard(in tabID: ReviewTabID) {
    reviewComposerKeyboardRequests.remove(tabID)
  }

  /// Text a close or switch would lose: an Edit left as it was loses nothing.
  func reviewComposerHoldsUnsavedText(in tabID: ReviewTabID) -> Bool {
    guard let composer = reviewComposers[tabID], let worktreeID = reviewWorktree(of: tabID),
      let draft = reviewDraft(in: tabID).trimmedOfAllWhitespaceOrNil
    else { return false }
    return draft != reviewComments(in: worktreeID).first { $0.id == composer.editing }?.text
  }

  /// Only a composer on screen: one hidden by the scope would block every +.
  private func composerHoldsUnsavedShownText(in tabID: ReviewTabID) -> Bool {
    guard let composer = reviewComposers[tabID], let worktreeID = reviewWorktree(of: tabID),
      composer.appliesUnder(fileTabScope(in: worktreeID)),
      tabHasLines(on: composer.side, ofFile: composer.path, in: tabID)
    else { return false }
    return reviewComposerHoldsUnsavedText(in: tabID)
  }

  /// Placement's rule: a side with no numbered line left, its file emptied or
  /// deleted and kept as last read, places no card.
  private func tabHasLines(on side: DiffSide, ofFile path: String, in tabID: ReviewTabID) -> Bool {
    (reviewRows(ofFile: path, in: tabID) ?? []).contains { line in
      side.shows(line.kind) && line.number(on: side) != nil
    }
  }
}

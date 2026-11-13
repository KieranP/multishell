import Foundation
import MultishellCore

extension AppModel {
  /// A line's + in the gutter, a drag down it, or Comment on Lines.
  /// Not over a composer holding text, which would lose what was typed.
  public func openReviewComposer(on selection: ReviewLineSelection, in tabID: FileTab.ID) {
    guard let tab = workspace.fileTab(tabID), !composerHoldsUnsavedShownText(in: tabID) else {
      return
    }
    let composer = ReviewComposer(
      side: selection.side,
      lines: selection.lines,
      quote: reviewQuote(of: selection.lines, on: selection.side, in: tabID),
      scope: fileTabScope(in: tab.worktreeID),
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
  public func startEditingReviewComment(_ id: ReviewComment.ID, in tabID: FileTab.ID) {
    guard let tab = workspace.fileTab(tabID), !composerHoldsUnsavedShownText(in: tabID),
      let comment = reviewComments(in: tab.worktreeID).first(where: { $0.id == id }),
      comment.isPending
    else { return }
    let composer = ReviewComposer(
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

  public func reviewDraft(in tabID: FileTab.ID) -> String {
    reviewDrafts[tabID] ?? ""
  }

  public func noteReviewDraft(_ text: String, in tabID: FileTab.ID) {
    reviewDrafts[tabID] = text
  }

  /// The keyboard goes back to the tab, the card's field leaving with the card.
  public func cancelReviewComposer(in tabID: FileTab.ID) {
    setIfChanged(\.reviewComposers[tabID], nil)
    reviewDrafts[tabID] = nil
    reviewComposerKeyboardRequests.remove(tabID)
    fileTabFocusRequest = tabID
  }

  /// Add comment, or Save while editing. Refused with no text or no lines
  /// read, the composer staying open.
  @discardableResult
  public func commitReviewComposer(in tabID: FileTab.ID) -> Bool {
    guard let composer = reviewComposers[tabID], let tab = workspace.fileTab(tabID),
      let text = reviewDraft(in: tabID).trimmedOfAllWhitespaceOrNil
    else { return false }
    let isEditingAPendingComment = reviewComments(in: tab.worktreeID).contains { comment in
      comment.id == composer.editing && comment.isPending
    }
    if let editing = composer.editing, isEditingAPendingComment {
      editReviewComment(editing, in: tab.worktreeID, text: text)
    } else {
      // A quote is what keeps the comment on its lines. An edit whose comment was
      // sent or removed meanwhile is kept as a new one, not lost.
      guard !composer.quote.isEmpty else { return false }
      var comment = ReviewComment(
        path: tab.path,
        side: composer.side,
        scope: composer.scope,
        lines: composer.lines,
        quote: composer.quote,
        text: text,
      )
      // Lines rewritten while it was typed no longer read as its quote.
      if reviewQuote(of: composer.lines, on: composer.side, in: tabID) != composer.quote {
        comment.noteLinesChanged()
      }
      guard addReviewComment(comment, in: tab.worktreeID) else { return false }
    }
    cancelReviewComposer(in: tabID)
    return true
  }

  /// The lines' text as the tab last read it, empty where it holds no rows.
  func reviewQuote(
    of lines: ClosedRange<Int>,
    on side: DiffSide,
    in tabID: FileTab.ID,
  ) -> [String] {
    guard case .text(let rows) = fileTabReadings[tabID]?.content else { return [] }
    // Walked rather than taken from the side's whole text, which copies every line.
    return rows.lines.compactMap { line in
      guard side.shows(line.kind), let number = line.number(on: side), lines.contains(number)
      else { return nil }
      return line.text
    }
  }

  /// Once per opening, so a card rebuilt by a layout switch leaves the keyboard be.
  public func reviewComposerAsksForKeyboard(in tabID: FileTab.ID) -> Bool {
    reviewComposerKeyboardRequests.contains(tabID)
  }

  public func noteReviewComposerTookKeyboard(in tabID: FileTab.ID) {
    reviewComposerKeyboardRequests.remove(tabID)
  }

  /// Text a close or switch would lose: an Edit left as it was loses nothing.
  func reviewComposerHoldsUnsavedText(in tabID: FileTab.ID) -> Bool {
    guard reviewComposers[tabID] != nil, let tab = workspace.fileTab(tabID),
      let draft = reviewDraft(in: tabID).trimmedOfAllWhitespaceOrNil
    else { return false }
    let editing = reviewComposers[tabID]?.editing
    return draft != reviewComments(in: tab.worktreeID).first { $0.id == editing }?.text
  }

  /// Only a composer on screen: one hidden by the scope would block every +.
  private func composerHoldsUnsavedShownText(in tabID: FileTab.ID) -> Bool {
    guard let composer = reviewComposers[tabID], let tab = workspace.fileTab(tabID),
      composer.appliesUnder(fileTabScope(in: tab.worktreeID)),
      tabHasLines(on: composer.side, in: tabID)
    else { return false }
    return reviewComposerHoldsUnsavedText(in: tabID)
  }

  /// Placement's rule: a side with no numbered line left, its file emptied or
  /// deleted and kept as last read, places no card.
  private func tabHasLines(on side: DiffSide, in tabID: FileTab.ID) -> Bool {
    guard case .text(let rows) = fileTabReadings[tabID]?.content else { return false }
    return rows.lines.contains { side.shows($0.kind) && $0.number(on: side) != nil }
  }
}

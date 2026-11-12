import MultishellAppCore
import MultishellCore
import SwiftUI

/// One placed card, a comment's or the composer's, acting through the model.
struct ReviewCard: View {
  let placement: ReviewCardPlacement
  let model: AppModel
  let tabID: FileTab.ID
  let theme: Theme

  var body: some View {
    switch placement.card {
    case .comment(let comment, let isSelected):
      ReviewCommentCard(
        comment: comment,
        isSelected: isSelected,
        theme: theme,
        metrics: model.metrics,
        edit: { model.startEditingReviewComment(comment.id, in: tabID) },
        remove: { model.removeReviewComment(comment.id, in: tabID) },
      )

    case .composer(let composer):
      ReviewComposerCard(
        composer: composer,
        draft: model.reviewDraft(in: tabID),
        theme: theme,
        metrics: model.metrics,
        noteDraft: { model.noteReviewDraft($0, in: tabID) },
        commit: { model.commitReviewComposer(in: tabID) },
        cancel: { model.cancelReviewComposer(in: tabID) },
        takesKeyboardOnAppear: model.reviewComposerAsksForKeyboard(in: tabID),
        onTookKeyboard: { model.noteReviewComposerTookKeyboard(in: tabID) },
      )
    }
  }
}

import MultishellAppCore
import SwiftUI

/// The new-worktree sheet's branch rows: a name and a base for a new branch,
/// or a pick of an existing one.
struct NewWorktreeBranchFields: View {
  @Binding var draft: NewWorktreeDraft
  let prefix: String
  let checkedOut: Set<String>

  var body: some View {
    if draft.createsBranch { newBranchFields } else { existingBranchFields }
  }

  @ViewBuilder
  private var newBranchFields: some View {
    LabeledContent(t("sheet.branch")) {
      HStack(spacing: 2) {
        if !prefix.isEmpty {
          Text(prefix)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        TextField("", text: $draft.branch, prompt: Text(t("sheet.branch-prompt")))
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
      }
    }
    if draft.branchNameIsRefused {
      NewWorktreeFormNote(
        text: t("sheet.branch-refused"), symbol: "exclamationmark.triangle.fill", tint: .yellow)
    }
    Picker(t("sheet.based-on"), selection: $draft.baseBranch) {
      ForEach(draft.localBranches, id: \.self, content: Text.init)
      if !draft.remoteBranches.isEmpty {
        Divider()
        ForEach(draft.remoteBranches, id: \.self, content: Text.init)
      }
    }
  }

  @ViewBuilder
  private var existingBranchFields: some View {
    // Local branches only. A large repository has hundreds of remote ones,
    // and a fresh clone with nothing local to pick is told so instead.
    if draft.showsAllCheckedOutNote(checkedOut: checkedOut) {
      NewWorktreeFormNote(
        text: t("sheet.all-branches-checked-out"), symbol: "info.circle", tint: .secondary,
        dimsText: true)
    } else {
      Picker(t("sheet.branch"), selection: $draft.branch) {
        ForEach(draft.availableBranches(checkedOut: checkedOut), id: \.self, content: Text.init)
      }
    }
  }
}

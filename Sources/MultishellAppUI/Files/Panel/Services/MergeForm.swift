import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The pull request page's merge form, drawn in place of the page: the method,
/// the commit's subject and message as GitHub would write them, and the merge.
struct MergeForm: View {
  /// Low enough that the buttons stay on screen in the shortest window.
  private static let messageMinHeight: Double = 60

  let model: AppModel
  let worktree: Worktree
  let pullRequest: PullRequest
  let pending: PendingMerge
  let theme: Theme

  var body: some View {
    let hostName = model.pullRequestHostName(of: worktree) ?? ""
    let base = pullRequest.baseBranch
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(pending.heading(base: base))
          .font(model.metrics.font(size: model.metrics.secondary, weight: .semibold))
          .foregroundStyle(theme.filesPanel.text)
        if let lede = pending.lede(hostName: hostName) {
          caption(lede)
        }
      }
      switch pending.content {
      case .methods(let methods, let chosen):
        methodPicker(methods, chosen: chosen)
        if let note = pending.noMessageNote(base: base) {
          caption(note)
          Spacer(minLength: 0)
        } else {
          messageFields
        }

      case .unread:
        caption(model.mergeReadProblem(of: worktree) ?? "")
        Spacer(minLength: 0)

      case .reading:
        HStack(spacing: 6) {
          ProgressView().controlSize(.small)
          caption(PendingMerge.readingText(hostName: hostName))
        }
        Spacer(minLength: 0)
      }
      if let status = pending.statusNote(hostName: hostName) {
        caption(status)
      }
      Divider()
      buttons
        .layoutPriority(1)
    }
    .padding(UIMetrics.servicePageSideInset)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var messageFields: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          fieldLabel(t("merge-form.subject"))
          Spacer(minLength: 0)
          if pending.isEdited {
            Button(t("merge-form.restore-default")) { model.restoreMergeMessage(for: worktree) }
              .buttonStyle(.link)
              .font(model.metrics.font(size: model.metrics.caption))
          }
        }
        TextField(
          t("merge-form.subject"),
          text: Binding(
            get: { pending.message?.subject ?? "" },
            set: { model.setMergeSubject($0, for: worktree) },
          ),
        )
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
      }
      VStack(alignment: .leading, spacing: 5) {
        fieldLabel(t("merge-form.message"))
        MonospacedTextEditor(
          text: Binding(
            get: { pending.message?.body ?? "" },
            set: { model.setMergeBody($0, for: worktree) },
          ),
          fontSize: model.metrics.caption,
          fill: theme.header.background,
          border: theme.filesPanel.border,
          minHeight: Self.messageMinHeight,
          maxHeight: .infinity,
        )
        .accessibilityLabel(t("merge-form.message"))
      }
    }
    .disabled(!pending.isEditable)
  }

  private var buttons: some View {
    HStack(spacing: 8) {
      Spacer(minLength: 0)
      if pending.isSending {
        ProgressView().controlSize(.small)
      }
      Button(pending.dismissTitle) { model.dismissMergeForm(of: worktree) }
        .disabled(pending.isSending)
      if let confirmTitle = pending.confirmTitle {
        Button(confirmTitle) {
          Task { await model.confirmMerge(of: worktree) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!pending.canConfirm)
      }
    }
    .controlSize(.small)
  }

  private func methodPicker(
    _ methods: [PullRequestMergeMethod],
    chosen: PullRequestMergeMethod,
  ) -> some View {
    Picker(
      t("merge-form.method"),
      selection: Binding(
        get: { chosen },
        set: { model.chooseMergeMethod($0, for: worktree) },
      ),
    ) {
      ForEach(methods, id: \.self) { method in
        Text(method.name).tag(method)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .disabled(!pending.isEditable)
  }

  private func fieldLabel(_ text: String) -> some View {
    Text(text)
      .font(model.metrics.font(size: model.metrics.caption, weight: .semibold))
      .foregroundStyle(theme.filesPanel.textSecondary)
  }

  private func caption(_ text: String) -> some View {
    Text(text)
      .font(model.metrics.font(size: model.metrics.caption))
      .foregroundStyle(theme.filesPanel.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

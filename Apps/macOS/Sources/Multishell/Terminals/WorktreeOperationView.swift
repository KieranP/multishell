import MultishellAppCore
import MultishellCore
import SwiftUI

/// What the detail pane shows while a create or remove runs: the stage, a
/// Cancel where one can end early, and after a failure what it said.
struct WorktreeOperationView: View {
  let operation: WorktreeOperation
  let theme: Theme
  let cancel: () -> Void
  let dismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      if operation.isRunning {
        ProgressView()
          .controlSize(.large)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 34, weight: .light))
          .foregroundStyle(theme.ansiRGB[1].color)
      }
      Text(operation.title)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .padding(.top, 20)
      Text(operation.detail)
        .font(.system(size: 13))
        .foregroundStyle(theme.textSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 380)
        .padding(.top, 6)
      if operation.isRunning, let help = operation.step.cancelHelp {
        Button(t("action.cancel"), action: cancel)
          .padding(.top, 18)
          .help(help)
      }
      if let failure = operation.failure {
        ScrollView(.vertical) {
          Text(failure)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(maxWidth: 520, maxHeight: 180)
        .background(theme.chromeColor, in: RoundedRectangle(cornerRadius: 6))
        .padding(.top, 18)
        // No Return binding: a window-wide default action would also fire
        // from the sidebar's filter field.
        Button(t("action.dismiss"), action: dismiss)
          .buttonStyle(.borderedProminent)
          .padding(.top, 18)
      }
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

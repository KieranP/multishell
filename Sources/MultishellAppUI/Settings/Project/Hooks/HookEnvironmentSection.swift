import MultishellAppCore
import MultishellGitKit
import SwiftUI

/// The variables a hook is run with, each with a button to copy its name.
struct HookEnvironmentSection: View {
  let model: AppModel

  var body: some View {
    Section {
      ForEach(HookVariable.allCases, id: \.self) { variable in
        LabeledContent {
          Text(variable.meaning).foregroundStyle(.secondary)
        } label: {
          HStack(spacing: 4) {
            Text(variable.name).font(
              .system(size: UIMetrics.unscaledMonospacedSize, design: .monospaced))
            CopyButton("$\(variable.name)", model: model)
          }
        }
      }
    } header: {
      InfoLabel(sectionHeader: t("hooks.environment"), info: t("hooks.environment-info"))
    }
  }
}

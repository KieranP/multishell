import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// The variables a hook is run with, each with a button to copy its name.
struct HookVariablesSection: View {
  let model: AppModel

  var body: some View {
    Section {
      ForEach(HookVariable.allCases, id: \.self) { variable in
        LabeledContent {
          Text(variable.meaning).foregroundStyle(.secondary)
        } label: {
          HStack(spacing: 4) {
            Text(variable.name).font(.system(size: 11, design: .monospaced))
            CopyButton("$\(variable.name)", model: model)
          }
        }
      }
    } header: {
      InfoLabel(t("hooks.environment"), info: t("hooks.environment-info"), spacing: 6)
    }
  }
}

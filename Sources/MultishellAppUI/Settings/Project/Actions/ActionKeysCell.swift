import MultishellAppCore
import MultishellCore
import SwiftUI

/// An action's keys, recorded in place as a Shortcuts row records a command's,
/// judged by the same rules. What a key does is the model's to say.
struct ActionKeysCell: View {
  let model: AppModel
  let project: Project
  let name: String

  var body: some View {
    let keys = model.ownSettings(of: project).actionShortcuts.keys(for: name)
    let recording = model.actionKeysRecording(forAction: name, in: project)
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        if recording != nil {
          ShortcutRecorder(take: take)
        } else if let keys {
          ShortcutKeysButton(
            text: keys.glyphs,
            help: t("actions.keys-help", name),
            record: startRecording,
          )
          SettingsSymbolButton(symbol: "xmark.circle", help: t("actions.keys-clear-help", name)) {
            model.clearActionKeys(forAction: name, in: project)
          }
        } else {
          OverrideStartButton(help: t("actions.keys-help", name), start: startRecording)
        }
      }
      switch model.actionKeysNote(forAction: name, in: project) {
      case .refusal(let refusal): KeysNote(text: refusal.text, color: .red)
      case .warning(let warning): KeysNote(text: warning.text, color: .orange)
      case nil: EmptyView()
      }
    }
  }

  private func startRecording() {
    model.startRecordingActionKeys(forAction: name, in: project)
  }

  private func take(_ input: ShortcutRecorderInput) {
    switch input {
    case .keys(let keys): model.submitRecordedActionKeys(keys, forAction: name, in: project)
    case .clear: model.clearRecordedActionKeys(forAction: name, in: project)
    case .cancel: model.endActionKeysRecording()
    case .ignored: break
    }
  }
}

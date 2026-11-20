import MultishellAppCore
import MultishellCore
import SwiftUI

/// A command's row on the Shortcuts page: its menu title, its default keys,
/// and the user's, recorded in place. What a key does is the model's to say.
struct ShortcutRow: View {
  let model: AppModel
  let command: ShortcutCommand

  var body: some View {
    let isChanged = model.isShortcutChanged(command)
    VStack(alignment: .leading, spacing: 4) {
      OverrideColumns {
        Text(command.menuTitle)
          .fontWeight(isChanged ? .semibold : .regular)
      } global: {
        Text(command.defaultCombination.glyphs)
          .foregroundStyle(SettingsColors.secondaryText)
      } override: {
        yours(isChanged: isChanged)
      }
      notes
    }
  }

  private var step: ShortcutEditing.Step? {
    model.shortcutEditingStep(for: command)
  }

  @ViewBuilder private var notes: some View {
    switch step {
    case .recording(let refusal):
      if let refusal { note(refusal.text, color: .red) }
      note(t("shortcuts.recording-hint"), color: SettingsColors.secondaryText)

    case .confirming(let keys, let holder):
      HStack(spacing: 8) {
        note(t("shortcuts.taken", keys.glyphs, holder.menuTitle), color: .orange)
        Spacer(minLength: 0)
        Button(t("action.cancel"), action: model.endShortcutsPageEdit)
        Button(t("shortcuts.replace"), action: model.replaceAskedShortcut)
          .buttonStyle(.borderedProminent)
      }

    case nil:
      if let warning = model.shortcutWarning(for: command) { note(warning.text, color: .orange) }
      if let holder = model.commandHoldingDefault(of: command) {
        note(
          t("shortcuts.default-taken", command.defaultCombination.glyphs, holder.menuTitle),
          color: .orange,
        )
      }
    }
  }

  @ViewBuilder
  private func yours(isChanged: Bool) -> some View {
    if command.isFixed {
      Label(t("shortcuts.fixed"), systemImage: "lock")
        .font(.system(size: UIMetrics.settingsControlTextSize))
        .foregroundStyle(SettingsColors.secondaryText)
    } else if case .recording = step {
      ShortcutRecorder(take: take)
    } else if case .confirming(let keys, _) = step {
      Text(keys.glyphs)
        .shortcutKeysFace()
        .foregroundStyle(SettingsColors.secondaryText)
    } else if isChanged {
      ShortcutKeysButton(
        text: model.shortcutKeys(for: command)?.glyphs ?? t("shortcuts.none"),
        help: t("shortcuts.change-help", command.menuTitle),
        record: startRecording,
      )
      SettingsSymbolButton(
        symbol: "arrow.uturn.backward",
        help: t("shortcuts.reset-help", command.defaultCombination.glyphs),
      ) {
        model.resetShortcut(command)
      }
    } else {
      OverrideStartButton(
        help: t("shortcuts.change-help", command.menuTitle),
        start: startRecording,
      )
    }
  }

  private func note(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: UIMetrics.settingsSmallTextSize))
      .foregroundStyle(color)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func startRecording() {
    model.startRecordingShortcut(for: command)
  }

  private func take(_ input: ShortcutRecorderInput) {
    switch input {
    case .keys(let keys): model.submitRecordedShortcut(keys, for: command)
    case .cancel: model.endShortcutsPageEdit()
    case .clear: model.clearRecordedShortcut(for: command)
    case .ignored: break
    }
  }
}

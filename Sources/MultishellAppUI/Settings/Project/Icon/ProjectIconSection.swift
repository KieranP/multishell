import MultishellAppCore
import MultishellCore
import SwiftUI

/// The glyph and tint the sidebar draws. The controls show what is drawn, the
/// repository's icon included, and a change writes the user's over it.
struct ProjectIconSection: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let own = model.ownSettings(of: project)
    let settings = model.effectiveSettings(for: project)
    let kind = settings.iconKind
    let takesIconFromSharedFile = own.takesIconFromSharedFile(
      project.sharedSettingsSnapshot.confined
    )
    Section(t("project.icon")) {
      InfoLabeledContent(t("project.icon-label"), info: t("project.icon-info")) {
        IconPicker(kind: kind, tint: tint(settings)) { model.setIconGlyph($0, for: project) }
      }
      InfoLabeledContent(t("project.tint-label"), info: t("project.tint-info")) {
        HStack(spacing: 5) {
          swatch(nil, settings: settings, color: model.currentTheme.textSecondary)
          ForEach(0..<Theme.ansiSlotCount, id: \.self) { slot in
            swatch(slot, settings: settings, color: model.currentTheme.ansiRGB(slot).color)
          }
        }
      }
      if takesIconFromSharedFile {
        SettingsCaption(t("project.icon-from-shared", SharedProjectSettings.fileName))
      }
    }
  }

  /// Untinted, the system's grey, not the theme's: this window follows the
  /// system appearance, and a dark theme's grey vanished on a light page.
  private func tint(_ settings: ProjectSettings) -> Color {
    model.currentTheme.iconTint(settings.iconTint, untinted: .secondary)
  }

  private func swatch(_ slot: Int?, settings: ProjectSettings, color: Color) -> TintSwatch {
    TintSwatch(slot: slot, color: color, isSelected: settings.iconTint == slot) {
      model.setIconTint(slot, for: project)
    }
  }
}

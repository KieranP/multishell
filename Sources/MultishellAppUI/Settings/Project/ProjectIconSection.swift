import MultishellAppCore
import MultishellCore
import SwiftUI

/// The glyph and tint the sidebar draws. The controls show what is drawn, the
/// repository's icon included, and a change writes the user's over it.
struct ProjectIconSection: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let own = model.settings(of: project)
    let settings = model.effectiveSettings(for: project)
    let kind = ProjectIcon.kind(of: settings.iconGlyph)
    let fromFile = own.takesIconFromSharedFile(project.sharedSettings.confined)
    Section(t("project.icon")) {
      InfoLabeledContent(t("project.icon-label"), info: t("project.icon-info")) {
        IconPicker(kind: kind, tint: tint(settings)) { glyph in
          model.setting(\.iconGlyph, of: project).wrappedValue = glyph
        }
      }
      InfoLabeledContent(t("project.tint-label"), info: t("project.tint-info")) {
        HStack(spacing: 5) {
          swatch(nil, shown: settings, color: model.currentTheme.textSecondary)
          ForEach(0..<16, id: \.self) { slot in
            swatch(slot, shown: settings, color: model.currentTheme.ansiRGB(slot).color)
          }
        }
      }
      if fromFile {
        SettingsCaption(t("project.icon-from-shared", SharedProjectSettings.fileName))
      }
    }
  }

  /// Untinted, the system's grey, not the theme's: this window follows the
  /// system appearance, and a dark theme's grey vanished on a light page.
  private func tint(_ settings: ProjectSettings) -> Color {
    settings.iconTint.map { model.currentTheme.ansiRGB($0).color } ?? .secondary
  }

  private func swatch(_ slot: Int?, shown: ProjectSettings, color: Color) -> some View {
    let selected = shown.iconTint == slot
    return Button {
      model.setting(\.iconTint, of: project).wrappedValue = slot
    } label: {
      ZStack {
        // Outlined, or the theme's white vanishes on a light page and its
        // black on a dark one.
        Circle().fill(color).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
          .frame(width: 14, height: 14)
        if slot == nil {
          Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
        }
      }
      .overlay {
        if selected { Circle().strokeBorder(Color.primary, lineWidth: 1.5).padding(-2.5) }
      }
      .frame(width: 18, height: 18)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(slot.map { Theme.ansiSlotNames[$0] } ?? t("project.no-tint"))
    .accessibilityLabel(slot.map { Theme.ansiSlotNames[$0] } ?? t("project.no-tint"))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

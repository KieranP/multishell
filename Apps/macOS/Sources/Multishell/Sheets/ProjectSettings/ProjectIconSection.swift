import MultishellAppCore
import MultishellCore
import SwiftUI

/// The glyph and tint the sidebar draws for the project. One palette sets
/// the glyph. The controls show what is drawn, the repository's icon
/// included, and a change writes the user's own settings over it.
struct ProjectIconSection: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let own = model.settings(of: project)
    let settings = model.effectiveSettings(for: model.current(project))
    let kind = ProjectIcon.kind(of: settings.iconGlyph)
    let shared = model.sharedSettings[project.id]
    // Read the same way `ProjectSettings.layered` does, or the caption and
    // the icon disagree: a glyph that is not a symbol name is a gap on
    // either side, so a leftover emoji of the user's does not stop the
    // file's icon being the one in force, and one in the file is not it.
    let fromFile =
      (ProjectIcon.symbolName(own.iconGlyph) == nil
        && ProjectIcon.symbolName(shared?.iconGlyph) != nil)
      || (own.iconTint == nil && ProjectIcon.validTint(shared?.iconTint) != nil)
    Section("Icon") {
      InfoRow(
        "Icon:",
        info:
          "Drawn in the sidebar, the header and the project picker in place of the folder. The palette is grouped by what a symbol is of, with jumps to each group along the foot; the field at the top matches both a symbol's name and what it is used for, so \"database\", \"git\" and \"docker\" all find something. Down from the field moves into the grid, the arrows walk it and Return picks. The folder is the first cell and is what a project has until one is picked."
      ) {
        IconPicker(kind: kind, tint: tint(settings)) { glyph in
          model.setting(\.iconGlyph, of: project).wrappedValue = glyph
        }
      }
      InfoRow(
        "Tint:",
        info:
          "One of the theme's sixteen colours, so a later theme change keeps the icon in step with the terminal. Applies to symbols and the folder."
      ) {
        HStack(spacing: 5) {
          swatch(nil, shown: settings, color: model.currentTheme.textSecondary)
          ForEach(0..<16, id: \.self) { slot in
            swatch(slot, shown: settings, color: model.currentTheme.ansiRGB[slot].color)
          }
        }
      }
      if fromFile {
        SettingsCaption("From \(SharedProjectSettings.fileName). A choice here replaces it.")
      }
    }
  }

  private func tint(_ settings: ProjectSettings) -> Color {
    settings.iconTint.map { model.currentTheme.ansiRGB[$0].color }
      ?? model.currentTheme.textSecondary
  }

  private func swatch(_ slot: Int?, shown: ProjectSettings, color: Color) -> some View {
    let selected = shown.iconTint == slot
    return Button {
      model.setting(\.iconTint, of: project).wrappedValue = slot
    } label: {
      ZStack {
        Circle().fill(color).frame(width: 14, height: 14)
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
    .help(slot.map { Theme.ansiSlotNames[$0] } ?? "No tint")
  }
}

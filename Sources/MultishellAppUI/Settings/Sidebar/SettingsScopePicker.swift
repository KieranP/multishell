import MultishellAppCore
import MultishellCore
import SwiftUI

/// The card atop the settings sidebar: whose settings are shown, All Projects
/// or one project in the sidebar's order, beside that project's own icon.
struct SettingsScopePicker: View {
  let model: AppModel
  let scope: SettingsScope

  var body: some View {
    Menu {
      Picker(
        t("settings.scope"),
        selection: Binding(get: { scope }, set: { model.setSettingsScope($0) }),
      ) {
        Text(t("settings.all-projects")).tag(SettingsScope.allProjects)
        Divider()
        ForEach(model.workspace.projects) { project in
          Text(project.name).tag(SettingsScope.project(project.id))
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
    } label: {
      HStack(spacing: 8) {
        tile
        HStack(spacing: 4) {
          Text(scopeName)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down")
            .accessibilityHidden(true)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(SettingsColors.secondaryText)
        }
      }
      .padding(UIMetrics.settingsScopeCardInset)
      .settingsCardFace(radius: UIMetrics.settingsScopeCardRadius)
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .accessibilityLabel(t("settings.scope"))
    .accessibilityValue(scopeName)
  }

  /// A gear for All Projects, else the project's glyph on its tint.
  @ViewBuilder private var tile: some View {
    if let project = scopeProject {
      let settings = model.effectiveSettings(for: project)
      let untinted = SettingsPage.general.tileColor
      SettingsTile(
        side: UIMetrics.settingsScopeTileSide,
        radius: UIMetrics.settingsSidebarWellRadius,
        color: model.currentTheme.iconTint(settings.iconTint, untinted: untinted),
      ) {
        Image(systemName: settings.iconKind.symbolName)
          .accessibilityHidden(true)
          .font(.system(size: UIMetrics.settingsScopeGlyphSide))
      }
    } else {
      SettingsTile(
        side: UIMetrics.settingsScopeTileSide,
        radius: UIMetrics.settingsSidebarWellRadius,
        color: SettingsPage.general.tileColor,
      ) {
        SettingsPageGlyph(page: .general)
          .frame(width: UIMetrics.settingsScopeGlyphSide, height: UIMetrics.settingsScopeGlyphSide)
      }
    }
  }

  private var scopeName: String { model.settingsScopeName(of: scope) }

  private var scopeProject: Project? {
    guard case .project(let id) = scope else { return nil }
    return model.workspace.project(id)
  }
}

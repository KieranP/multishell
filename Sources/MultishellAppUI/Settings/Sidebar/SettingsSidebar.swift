import MultishellAppCore
import SwiftUI

/// The settings window's sidebar: whose settings, then their pages. A split
/// page lists its parts beneath it, its own row opening the first.
struct SettingsSidebar: View {
  let model: AppModel
  let location: SettingsLocation

  var body: some View {
    let pages = shownPages
    VStack(alignment: .leading, spacing: UIMetrics.settingsSidebarSpacing) {
      SettingsSearchField(text: searchText)
      SettingsScopePicker(model: model, scope: location.scope)
      ScrollView {
        VStack(spacing: 1) {
          ForEach(pages, id: \.self, content: rows)
        }
      }
      .scrollEdgeEffectHidden(true, for: .top)
      .overlay {
        if pages.isEmpty { ContentUnavailableView.search(text: model.settingsSearchText) }
      }
    }
    .padding(.top, UIMetrics.settingsSidebarTopInset)
    .padding(.horizontal, UIMetrics.settingsSidebarInset)
    .padding(.bottom, UIMetrics.settingsSidebarInset)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(SettingsColors.sidebar)
    .focusable()
    .focusEffectDisabled()
    .onKeyPress(.upArrow) { step(-1) }
    .onKeyPress(.downArrow) { step(1) }
  }

  private var shownPages: [SettingsPage] {
    SettingsSearch.pages(in: location.scope, matching: model.settingsSearchText) { page in
      page.searchTerms(in: location.scope)
    }
  }

  private var searchText: Binding<String> {
    Binding(get: { model.settingsSearchText }, set: { model.setSettingsSearchText($0) })
  }

  @ViewBuilder
  private func rows(_ page: SettingsPage) -> some View {
    let sections = page.sections(in: location.scope)
    if let first = sections.first {
      SettingsSidebarRow(title: page.title, page: page, isSelected: location.selects(page)) {
        show(first)
      }
      if first.isPart {
        ForEach(sections, id: \.self) { section in
          SettingsSidebarRow(
            title: section.partTitle ?? page.title,
            page: nil,
            isSelected: location.section == section,
          ) { show(section) }
        }
      }
    }
  }

  private func step(_ offset: Int) -> KeyPress.Result {
    model.stepSettingsSection(by: offset, among: shownPages)
    return .handled
  }

  private func show(_ section: SettingsSection) {
    model.showSettings(section, in: location.scope)
  }
}

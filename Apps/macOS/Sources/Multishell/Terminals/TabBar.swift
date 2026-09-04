import MultishellCore
import SwiftUI

struct TabBar: View {
  let model: AppModel
  let tabs: [TerminalTab]
  let activeID: TerminalTab.ID?
  let theme: Theme

  @State private var editingTabID: TerminalTab.ID?
  @State private var draftTitle = ""
  @FocusState private var titleFieldFocused: Bool

  var body: some View {
    HStack(spacing: 0) {
      ForEach(tabs) { tab in
        tabButton(tab)
          .frame(maxWidth: 190)
          .draggable(tab.id.uuidString)
          .dropDestination(for: String.self) { dropped, _ in
            guard let raw = dropped.first, let moving = UUID(uuidString: raw) else { return false }
            model.moveTab(moving, before: tab.id)
            return true
          }
      }
      // New tab sits with the tabs. With no tabs there is no strip, and the
      // header's + takes over.
      Button {
        model.newTab()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: model.metrics.icon, weight: .medium))
          .foregroundStyle(theme.textSecondary)
          .frame(width: 28, height: model.metrics.tabHeight)
      }
      .buttonStyle(.plain)
      .help("New Tab (⌘T)")

      Spacer(minLength: 0)
    }
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
  }

  private func tabButton(_ tab: TerminalTab) -> some View {
    let isActive = tab.id == activeID
    let text = isActive ? theme.textPrimary : theme.textSecondary
    return HStack(spacing: 7) {
      if model.hasUnseenActivity(tab) {
        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
      } else {
        Image(systemName: tab.isSplit ? "rectangle.split.2x1" : "apple.terminal")
          .font(.system(size: model.metrics.icon))
          .foregroundStyle(text)
      }

      if editingTabID == tab.id {
        titleField(tab)
      } else {
        Text(model.title(of: tab))
          .font(.system(size: model.metrics.secondary, weight: isActive ? .medium : .regular))
          .foregroundStyle(text)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)

      if isActive, editingTabID != tab.id {
        Button {
          model.closeActiveTab()
        } label: {
          Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textSecondary)
      }
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(isActive ? theme.backgroundColor : .clear)
    .overlay(alignment: .trailing) {
      if !isActive { theme.hairline.frame(width: 0.5).padding(.vertical, 8) }
    }
    .contentShape(.rect)
    // Simultaneous, not sequential: a plain double-tap recognizer makes
    // SwiftUI hold the single tap until it is sure no second is coming,
    // and tab switching should not lag by that timeout.
    .onTapGesture { model.activate(tab) }
    .simultaneousGesture(TapGesture(count: 2).onEnded { beginEditing(tab) })
    .contextMenu {
      Button("Rename…") { beginEditing(tab) }
      if tab.customTitle != nil {
        Button("Use Shell Title") { model.renameTab(tab.id, to: nil) }
      }
    }
  }

  /// Return commits, Escape cancels, leaving the field commits. An empty
  /// name clears the custom title rather than storing a blank one.
  private func titleField(_ tab: TerminalTab) -> some View {
    TextField("Tab name", text: $draftTitle)
      .textFieldStyle(.plain)
      .font(.system(size: model.metrics.secondary, weight: .medium))
      .foregroundStyle(theme.textPrimary)
      .focused($titleFieldFocused)
      .onSubmit { commit(tab) }
      .onExitCommand { editingTabID = nil }
      .onChange(of: titleFieldFocused) { _, focused in
        if !focused, editingTabID == tab.id { commit(tab) }
      }
  }

  private func beginEditing(_ tab: TerminalTab) {
    draftTitle = tab.customTitle ?? model.title(of: tab)
    editingTabID = tab.id
    titleFieldFocused = true
  }

  private func commit(_ tab: TerminalTab) {
    model.renameTab(tab.id, to: draftTitle)
    editingTabID = nil
  }
}

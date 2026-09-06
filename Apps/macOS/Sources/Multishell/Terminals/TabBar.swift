import MultishellAppCore
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
      // header's actions menu or Cmd+T takes over.
      Button {
        model.newTab()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: model.metrics.icon, weight: .medium))
          .foregroundStyle(theme.textSecondary)
          .frame(width: 34, height: model.metrics.tabHeight)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help("New Tab (⌘T)")
      .accessibilityLabel("New Tab")

      Spacer(minLength: 0)
    }
    .frame(height: model.metrics.tabHeight)
    .background(theme.chromeColor)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
  }

  private func tabButton(_ tab: TerminalTab) -> some View {
    let isActive = tab.id == activeID
    let text = isActive ? theme.textPrimary : theme.textSecondary
    let state = model.state(of: tab)
    return HStack(spacing: 7) {
      if let state {
        // A button, so a click on the dot clears a Working state whose agent
        // is long gone without activating the tab first.
        Button {
          model.clearState(of: tab)
        } label: {
          Circle().fill(theme.color(for: state)).frame(width: 7, height: 7)
            .frame(width: 14, height: 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("\(state.displayName). Click to clear.")
        .accessibilityLabel("\(state.displayName). Clear status")
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
          Image(systemName: "xmark")
            .font(.system(size: 9, weight: .semibold))
            .frame(width: 20, height: 20)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textSecondary)
        .accessibilityLabel("Close Tab")
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
    // The buttons inside keep their own labels; the row's label describes
    // the tab. `.contain` rather than `.combine`, which would read the
    // close button's label into the tab's.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      AccessibilityText.tab(
        title: model.title(of: tab), isActive: isActive, isSplit: tab.isSplit, state: state)
    )
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: "Rename") { beginEditing(tab) }
    .contextMenu {
      Button("Rename…") { beginEditing(tab) }
      if tab.customTitle != nil {
        Button("Use Shell Title") { model.renameTab(tab.id, to: nil) }
      }
      if state != nil {
        Divider()
        Button("Clear Status") { model.clearState(of: tab) }
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

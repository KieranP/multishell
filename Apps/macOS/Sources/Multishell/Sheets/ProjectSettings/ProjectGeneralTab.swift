import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectGeneralTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    Form {
      Section {
        LabeledContent("Repository:") {
          HStack {
            Text(project.path.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
            IconButton.reveal { model.revealInFileBrowser(project.path) }
              .controlSize(.small)
          }
        }
        LabeledContent("Worktrees:") {
          HStack {
            Text("\(worktrees.count) discovered")
            IconButton.refresh(help: "Refresh from git") {
              Task { await model.refreshRequested(project) }
            }
            .controlSize(.small)
          }
        }
      }

      ProjectIconSection(model: model, project: project)

      Section {
        HStack(spacing: 8) {
          Button("Export") { model.exportSharedSettings(for: project) }
          InfoButton(
            "Writes this project's worktree path, branch prefix, hooks and icon, as they are in effect, to \(SharedProjectSettings.fileName) at the repository root, for the team to commit, replacing one already there. Anyone who adds the repository gets them as defaults under their own; they are asked once before its hooks run."
          )
          Spacer()
          Button("Remove Project…", role: .destructive) {
            model.requestProjectRemoval(project, from: .settings)
          }
          InfoButton(
            "Takes the project out of the sidebar and closes its terminals, after asking. Nothing on disk is touched."
          )
        }
      }
    }
    .formStyle(.grouped)
  }
}

/// The glyph and tint the sidebar draws for the project. Two controls set
/// one glyph: a symbol from the curated list, or an emoji typed or pasted
/// from the character palette; whichever was set last wins. The controls
/// show what is drawn, the repository's icon included, and a change writes
/// the user's own settings over it.
private struct ProjectIconSection: View {
  let model: AppModel
  let project: Project

  private static let emojiTag = "emoji"
  private static let folderTag = "folder"

  var body: some View {
    let current = model.workspace.project(project.id) ?? project
    let own = current.settings
    let settings = model.effectiveSettings(for: current)
    let kind = ProjectIcon.kind(of: settings.iconGlyph)
    let shared = model.sharedSettings[project.id]
    let fromFile =
      (own.iconGlyph == nil && shared?.iconGlyph != nil)
      || (own.iconTint == nil && ProjectIcon.validTint(shared?.iconTint) != nil)
    Section("Icon") {
      InfoRow(
        "Symbol:",
        info:
          "Drawn in the sidebar, the header and the project picker in place of the folder. Whichever was set last wins: picking a symbol replaces an emoji, typing an emoji replaces the symbol."
      ) {
        Picker("Symbol:", selection: symbol(own, kind: kind)) {
          Label("Folder", systemImage: "folder").tag(Self.folderTag)
          if case .emoji(let emoji) = kind {
            Text("\(emoji)  Emoji").tag(Self.emojiTag)
          }
          Divider()
          ForEach(ProjectIcon.symbols.filter { $0 != "folder" }.sorted(), id: \.self) { name in
            Label(name, systemImage: name).tag(name)
          }
        }
      }
      InfoRow(
        "Emoji:",
        info:
          "One character; ⌃⌘Space opens the palette. Emoji keep their own colours, so the tint does not apply."
      ) {
        TextField("Emoji:", text: emoji(own, kind: kind), prompt: Text("Optional"))
          .frame(width: 60)
      }
      InfoRow(
        "Tint:",
        info:
          "One of the theme's sixteen colours, so a later theme change keeps the icon in step with the terminal. Applies to symbols and the folder."
      ) {
        HStack(spacing: 5) {
          swatch(nil, own: own, shown: settings, color: model.currentTheme.textSecondary)
          ForEach(0..<16, id: \.self) { slot in
            swatch(slot, own: own, shown: settings, color: model.currentTheme.ansiRGB[slot].color)
          }
        }
      }
      if fromFile {
        SettingsCaption("From \(SharedProjectSettings.fileName). A choice here replaces it.")
      }
    }
  }

  private func symbol(_ settings: ProjectSettings, kind: ProjectIcon.Kind) -> Binding<String> {
    Binding(
      get: {
        switch kind {
        case .folder: Self.folderTag
        case .emoji: Self.emojiTag
        case .symbol(let name): name
        }
      },
      set: { chosen in
        guard chosen != Self.emojiTag else { return }
        update(settings) { $0.iconGlyph = chosen == Self.folderTag ? nil : chosen }
      })
  }

  private func emoji(_ settings: ProjectSettings, kind: ProjectIcon.Kind) -> Binding<String> {
    Binding(
      get: {
        if case .emoji(let emoji) = kind { return emoji }
        return ""
      },
      set: { typed in
        switch ProjectIcon.kind(of: typed) {
        case .emoji(let emoji): update(settings) { $0.iconGlyph = emoji }
        case .folder, .symbol:
          // Cleared, or ASCII typed by mistake: back to the folder, unless a
          // symbol is what the glyph already is.
          if case .emoji = kind { update(settings) { $0.iconGlyph = nil } }
        }
      })
  }

  private func swatch(
    _ slot: Int?, own: ProjectSettings, shown: ProjectSettings, color: Color
  )
    -> some View
  {
    let selected = shown.iconTint == slot
    return Button {
      update(own) { $0.iconTint = slot }
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
    .help(slot.map { Self.slotNames[$0] } ?? "No tint")
  }

  private static let slotNames = [
    "Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White",
    "Bright black", "Bright red", "Bright green", "Bright yellow", "Bright blue",
    "Bright magenta", "Bright cyan", "Bright white",
  ]

  private func update(_ settings: ProjectSettings, _ change: (inout ProjectSettings) -> Void) {
    var updated = settings
    change(&updated)
    model.updateSettings(updated, for: project)
  }
}

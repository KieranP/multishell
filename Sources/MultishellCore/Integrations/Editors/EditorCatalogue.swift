import Foundation

/// The editors people install, as a static table. Ids are strings in the
/// workspace so a newer build's editor loads harmlessly on an older one.
public enum EditorCatalogue {
  public static let noneID = "none"
  /// A command template the user typed, with `{path}` for the worktree.
  public static let customID = "custom"

  public static let editors: [EditorDescriptor] = [
    EditorDescriptor(
      id: "vscode",
      name: "Visual Studio Code",
      kind: .application,
      bundleIdentifier: "com.microsoft.VSCode",
      executable: "code",
    ),
    EditorDescriptor(
      id: "cursor",
      name: "Cursor",
      kind: .application,
      bundleIdentifier: "com.todesktop.230313mzl4w4u92",
      executable: "cursor",
    ),
    EditorDescriptor(
      id: "zed",
      name: "Zed",
      kind: .application,
      bundleIdentifier: "dev.zed.Zed",
      executable: "zed",
    ),
    EditorDescriptor(
      id: "zed-preview",
      name: "Zed Preview",
      kind: .application,
      bundleIdentifier: "dev.zed.Zed-Preview",
    ),
    EditorDescriptor(
      id: "sublime",
      name: "Sublime Text",
      kind: .application,
      bundleIdentifier: "com.sublimetext.4",
      executable: "subl",
    ),
    EditorDescriptor(
      id: "xcode",
      name: "Xcode",
      kind: .application,
      bundleIdentifier: "com.apple.dt.Xcode",
    ),
    EditorDescriptor(
      id: "nova",
      name: "Nova",
      kind: .application,
      bundleIdentifier: "com.panic.Nova",
      executable: "nova",
    ),
    EditorDescriptor(
      id: "bbedit",
      name: "BBEdit",
      kind: .application,
      bundleIdentifier: "com.barebones.bbedit",
      executable: "bbedit",
    ),
    EditorDescriptor(
      id: "intellij",
      name: "IntelliJ IDEA",
      kind: .application,
      bundleIdentifier: "com.jetbrains.intellij",
      executable: "idea",
    ),
    EditorDescriptor(
      id: "webstorm",
      name: "WebStorm",
      kind: .application,
      bundleIdentifier: "com.jetbrains.WebStorm",
      executable: "webstorm",
    ),
    EditorDescriptor(
      id: "pycharm",
      name: "PyCharm",
      kind: .application,
      bundleIdentifier: "com.jetbrains.pycharm",
      executable: "pycharm",
    ),
    EditorDescriptor(
      id: "goland",
      name: "GoLand",
      kind: .application,
      bundleIdentifier: "com.jetbrains.goland",
      executable: "goland",
    ),
    EditorDescriptor(
      id: "rubymine",
      name: "RubyMine",
      kind: .application,
      bundleIdentifier: "com.jetbrains.rubymine",
      executable: "rubymine",
    ),
    EditorDescriptor(
      id: "clion",
      name: "CLion",
      kind: .application,
      bundleIdentifier: "com.jetbrains.CLion",
      executable: "clion",
    ),
    EditorDescriptor(
      id: "phpstorm",
      name: "PhpStorm",
      kind: .application,
      bundleIdentifier: "com.jetbrains.PhpStorm",
      executable: "phpstorm",
    ),
    EditorDescriptor(
      id: "rider",
      name: "Rider",
      kind: .application,
      bundleIdentifier: "com.jetbrains.rider",
      executable: "rider",
    ),
    EditorDescriptor(
      id: "android-studio",
      name: "Android Studio",
      kind: .application,
      bundleIdentifier: "com.google.android.studio",
      executable: "studio",
    ),
    EditorDescriptor(id: "nvim", name: "Neovim", kind: .terminal, executable: "nvim"),
    EditorDescriptor(id: "vim", name: "Vim", kind: .terminal, executable: "vim"),
    EditorDescriptor(id: "emacs", name: "Emacs", kind: .terminal, executable: "emacs"),
    EditorDescriptor(id: "helix", name: "Helix", kind: .terminal, executable: "hx"),
  ]

  public static func editor(_ id: String) -> EditorDescriptor? {
    editors.first { $0.id == id }
  }

  /// The id in force, or `nil` for none.
  static func effectiveID(_ id: String?) -> String? {
    ChosenID.effective(global: id, noneID: noneID)
  }
}

import Foundation

/// An editor Open in Editor can hand a worktree to.
public struct EditorDescriptor: Identifiable, Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// A Mac application, found by bundle identifier, or through its command
    /// line shim when the application lookup has nothing.
    case application
    /// Runs inside a terminal, so it opens as a new tab in the worktree.
    case terminal
  }

  public let id: String
  public let name: String
  public let kind: Kind
  /// How the platform finds the application; the Mac's is the bundle id.
  public let bundleIdentifier: String?
  /// A command on the login shell's PATH that opens a directory when given
  /// its path: `code`, `subl`, `nvim`.
  public let command: String?

  public init(
    id: String, name: String, kind: Kind, bundleIdentifier: String? = nil, command: String? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.bundleIdentifier = bundleIdentifier
    self.command = command
  }
}

/// The editors people install, as a static table. Ids are strings in the
/// workspace so a newer build's editor loads harmlessly on an older one.
public enum EditorCatalogue {
  public static let noneID = "none"
  /// A command template the user typed, with `{path}` for the worktree.
  public static let customID = "custom"

  public static let editors: [EditorDescriptor] = [
    EditorDescriptor(
      id: "vscode", name: "Visual Studio Code", kind: .application,
      bundleIdentifier: "com.microsoft.VSCode", command: "code"),
    EditorDescriptor(
      id: "cursor", name: "Cursor", kind: .application,
      bundleIdentifier: "com.todesktop.230313mzl4w4u92", command: "cursor"),
    EditorDescriptor(
      id: "zed", name: "Zed", kind: .application, bundleIdentifier: "dev.zed.Zed", command: "zed"),
    EditorDescriptor(
      id: "zed-preview", name: "Zed Preview", kind: .application,
      bundleIdentifier: "dev.zed.Zed-Preview"),
    EditorDescriptor(
      id: "sublime", name: "Sublime Text", kind: .application,
      bundleIdentifier: "com.sublimetext.4", command: "subl"),
    EditorDescriptor(
      id: "xcode", name: "Xcode", kind: .application, bundleIdentifier: "com.apple.dt.Xcode"),
    EditorDescriptor(
      id: "nova", name: "Nova", kind: .application, bundleIdentifier: "com.panic.Nova",
      command: "nova"),
    EditorDescriptor(
      id: "bbedit", name: "BBEdit", kind: .application, bundleIdentifier: "com.barebones.bbedit",
      command: "bbedit"),
    EditorDescriptor(
      id: "intellij", name: "IntelliJ IDEA", kind: .application,
      bundleIdentifier: "com.jetbrains.intellij", command: "idea"),
    EditorDescriptor(
      id: "webstorm", name: "WebStorm", kind: .application,
      bundleIdentifier: "com.jetbrains.WebStorm", command: "webstorm"),
    EditorDescriptor(
      id: "pycharm", name: "PyCharm", kind: .application,
      bundleIdentifier: "com.jetbrains.pycharm", command: "pycharm"),
    EditorDescriptor(
      id: "goland", name: "GoLand", kind: .application, bundleIdentifier: "com.jetbrains.goland",
      command: "goland"),
    EditorDescriptor(
      id: "rubymine", name: "RubyMine", kind: .application,
      bundleIdentifier: "com.jetbrains.rubymine", command: "rubymine"),
    EditorDescriptor(
      id: "clion", name: "CLion", kind: .application, bundleIdentifier: "com.jetbrains.CLion",
      command: "clion"),
    EditorDescriptor(
      id: "phpstorm", name: "PhpStorm", kind: .application,
      bundleIdentifier: "com.jetbrains.PhpStorm", command: "phpstorm"),
    EditorDescriptor(
      id: "rider", name: "Rider", kind: .application, bundleIdentifier: "com.jetbrains.rider",
      command: "rider"),
    EditorDescriptor(
      id: "android-studio", name: "Android Studio", kind: .application,
      bundleIdentifier: "com.google.android.studio", command: "studio"),
    EditorDescriptor(id: "nvim", name: "Neovim", kind: .terminal, command: "nvim"),
    EditorDescriptor(id: "vim", name: "Vim", kind: .terminal, command: "vim"),
    EditorDescriptor(id: "emacs", name: "Emacs", kind: .terminal, command: "emacs"),
    EditorDescriptor(id: "helix", name: "Helix", kind: .terminal, command: "hx"),
  ]

  public static func editor(_ id: String) -> EditorDescriptor? {
    editors.first { $0.id == id }
  }

  /// The id in force, or `nil` for none.
  public static func effectiveID(_ id: String?) -> String? {
    guard let id, !id.isEmpty, id != noneID else { return nil }
    return id
  }

  /// The user's template with `{path}` filled in, quoted for the shell. A
  /// template without the placeholder gets the path appended, which is what
  /// most editors' command lines take.
  public static func customCommandLine(_ template: String, path: URL) -> String? {
    let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let quoted = ShellQuoting.quote(path.path)
    guard trimmed.contains("{path}") else { return "\(trimmed) \(quoted)" }
    return trimmed.replacingOccurrences(of: "{path}", with: quoted)
  }
}

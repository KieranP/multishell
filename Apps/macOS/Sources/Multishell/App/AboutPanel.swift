import AppKit

/// The standard panel with the commit beside the build number, so a bug
/// report says which tree was installed; see Docs/develop/build.md.
enum AboutPanel {
  static let commitKey = "MultishellCommit"

  static func options(from info: [String: Any]) -> [NSApplication.AboutPanelOptionKey: Any] {
    guard let build = info["CFBundleVersion"] as? String,
      let commit = info[commitKey] as? String, !commit.isEmpty
    else { return [:] }
    return [.version: "\(build), \(commit)"]
  }

  @MainActor static func show() {
    NSApp.orderFrontStandardAboutPanel(options: options(from: Bundle.main.infoDictionary ?? [:]))
  }
}

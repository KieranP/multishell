import Foundation

/// Where Settings > Agents sends someone without Claude Code. The app never
/// runs the installer itself; it opens the guide and copies the line.
public enum ClaudeCodeInstall {
  public static let setupGuideURL = URL(string: "https://code.claude.com/docs/en/setup")!
  public static let installerCommand = "curl -fsSL https://claude.ai/install.sh | bash"
}

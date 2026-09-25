import Foundation

extension AppModel {
  public func revealInFileBrowser(_ url: URL) {
    platform.revealInFileBrowser(url)
  }

  public func copyToClipboard(_ text: String) {
    platform.copyToClipboard(text)
  }
}

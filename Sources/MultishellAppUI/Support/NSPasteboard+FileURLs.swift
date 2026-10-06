import AppKit

extension NSPasteboard {
  /// The files on it, a web address among them left out.
  var fileURLs: [URL] {
    readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
      ?? []
  }
}

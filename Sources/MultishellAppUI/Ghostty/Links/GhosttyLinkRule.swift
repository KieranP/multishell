import Darwin
import Foundation
import UniformTypeIdentifiers

/// Where a link clicked in a pane may be opened. Whatever runs in the pane wrote
/// it, so only the web, mail, text in the editor, and what launches nothing open.
enum GhosttyLinkRule {
  enum Opening: Equatable {
    case inDefaultApplication(URL)
    case inEditor(URL)
  }

  /// Each opened by an app that runs nothing of the file's. Kinds, not
  /// refusals, which missed what Shortcuts imports and Disk Utility mounts.
  private static let defaultApplicationTypes: [UTType] =
    [.audiovisualContent, .image, .pdf, .presentation, .spreadsheet, .zip, .gzip, .bz2]
    + [
      "public.tar-archive", "org.7-zip.7-zip-archive", "org.tukaani.xz-archive",
      "org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc",
      "org.oasis-open.opendocument.text", "com.apple.iwork.pages.sffpages",
    ].compactMap(UTType.init)

  /// What `ls --hyperlink` and `rg` put in a `file:` URL's host, read each time:
  /// macOS renames the Mac as its network changes.
  private static var thisMacsName: String {
    var name = [CChar](repeating: 0, count: 256)
    guard gethostname(&name, name.count) == 0 else { return "" }
    return String(decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
  }

  /// A Hangul filler or a combining grapheme joiner draws nothing either.
  private static let blankScalars: Set<UInt32> = [0x034F, 0x115F, 0x1160, 0x3164, 0xFFA0]

  /// Its target is not the text the pane shows, so only a file on this Mac
  /// opens, judged as any other; a web or mail target could be anyone's.
  static func opening(forHyperlink target: String, in directory: URL) -> Opening? {
    guard URL(string: target)?.scheme?.lowercased() == "file" else { return nil }
    return opening(for: target, in: directory)
  }

  static func opening(for text: String, in directory: URL) -> Opening? {
    guard !text.isEmpty, !text.unicodeScalars.contains(where: canDisguise) else { return nil }
    guard let url = URL(string: text), let scheme = url.scheme?.lowercased() else {
      return GhosttyLinkPath.existingPath(of: text, in: directory).flatMap(opening(forPath:))
    }
    switch scheme {
    case "http", "https":
      return url.host?.isEmpty == false ? .inDefaultApplication(url) : nil

    case "mailto":
      return hasRecipient(url) ? .inDefaultApplication(url) : nil

    case "file":
      guard url.query == nil, url.fragment == nil, isOnThisMac(url), url.path.hasPrefix("/")
      else { return nil }
      return GhosttyLinkPath.existingPath(of: url.path, in: directory).flatMap(opening(forPath:))

    default:
      return nil
    }
  }

  /// An address in the path, or a `to` in the query, which Mail fills in from.
  private static func hasRecipient(_ url: URL) -> Bool {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return false
    }
    let recipient = parts.queryItems?.first { $0.name.lowercased() == "to" }?.value
    return !parts.path.isEmpty || recipient?.isEmpty == false
  }

  private static func isOnThisMac(_ url: URL) -> Bool {
    guard let host = url.host?.lowercased(), !host.isEmpty else { return true }
    let name = thisMacsName.lowercased()
    return host == "localhost" || host == name || host + ".local" == name
  }

  /// Judged by what the path resolves to, so a harmless name linked to a
  /// program does not hide it, and only that target goes to a default app.
  private static func opening(forPath path: String) -> Opening? {
    guard path.hasPrefix("/"), let resolved = realpath(path, nil) else { return nil }
    defer { free(resolved) }
    let target = URL(filePath: String(cString: resolved))
    let values = try? target.resourceValues(forKeys: [
      .contentTypeKey, .isDirectoryKey, .isPackageKey, .isRegularFileKey,
    ])
    guard let values, values.isDirectory == true || values.isRegularFile == true else {
      return nil
    }
    if TextFileRule.opensAsText(target) {
      return .inEditor(nameForEditor(printed: path, resolving: target))
    }
    return opensInDefaultApplication(values) ? .inDefaultApplication(target) : nil
  }

  /// The name the pane printed keeps an editor inside a workspace opened
  /// through a symlink; after one, `..` names another file than on disk.
  private static func nameForEditor(printed path: String, resolving target: URL) -> URL {
    let printed = URL(filePath: path)
    return printed.pathComponents.contains("..") ? target : printed.standardized
  }

  /// A bundle hands its code to whatever opens it: a .prefPane to System Settings.
  private static func opensInDefaultApplication(_ values: URLResourceValues) -> Bool {
    if values.isDirectory == true { return values.isPackage != true }
    // macOS counts a .jar, a zip Java runs, and a macro-enabled .docm as runnable.
    guard let type = values.contentType, !type.conforms(to: .executable) else { return false }
    return defaultApplicationTypes.contains(where: type.conforms(to:))
  }

  /// Controls, bidirectional overrides and invisible characters, which could
  /// make a link read as one target while naming another.
  private static func canDisguise(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .control, .format, .lineSeparator, .paragraphSeparator:
      true

    default:
      blankScalars.contains(scalar.value) || scalar.properties.isVariationSelector
    }
  }
}

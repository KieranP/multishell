import AppKit
import MultishellAppCore

/// The images on the pasteboard saved as files a pane's shell can read, once
/// per copy, so the same images pasted again type the same paths.
@MainActor
enum PastedImageFile {
  /// Formats agents read, written as they came. TIFF alone is converted, the
  /// pasteboard offering a JPEG's TIFF too.
  private static let formatsKept: [(type: NSPasteboard.PasteboardType, pathExtension: String)] = [
    (.png, "png"),
    (NSPasteboard.PasteboardType("public.jpeg"), "jpg"),
    (NSPasteboard.PasteboardType("com.compuserve.gif"), "gif"),
    (NSPasteboard.PasteboardType("org.webmproject.webp"), "webp"),
  ]

  static let pasteboardTypes = formatsKept.map(\.type) + [.tiff]

  private static var lastSaved:
    (pasteboard: NSPasteboard.Name, changeCount: Int, dropsDirectory: URL, files: [URL])?

  /// This copy's files, one per item holding an image, in one directory and
  /// written now where `saving` and there are none yet; `isNew` where they were.
  static func files(
    for pasteboard: NSPasteboard,
    in dropsDirectory: URL,
    saving: Bool,
  ) -> (urls: [URL], directory: URL, isNew: Bool)? {
    let changeCount = pasteboard.changeCount
    if let saved = savedFiles(for: pasteboard, changeCount: changeCount, in: dropsDirectory) {
      let directory = saved[0].deletingLastPathComponent()
      // The user typing the path again is what must resolve for a week.
      if saving { DropCopies.keep(directory) }
      return (saved, directory, false)
    }
    guard saving else { return nil }
    var directory: URL?
    var files: [URL] = []
    for image in (pasteboard.pasteboardItems ?? []).lazy.compactMap(image(in:)) {
      guard let saveIn = directory ?? (try? DropCopies.makeDirectory(in: dropsDirectory)) else {
        return nil
      }
      directory = saveIn
      let name = files.isEmpty ? "pasted-image" : "pasted-image-\(files.count + 1)"
      let file = saveIn.appendingPathComponent("\(name).\(image.pathExtension)")
      do {
        try image.data.write(to: file)
      } catch {
        DropCopies.remove(saveIn)
        return nil
      }
      files.append(file)
    }
    guard let directory, !files.isEmpty else { return nil }
    lastSaved = (pasteboard.name, changeCount, dropsDirectory, files)
    return (files, directory, true)
  }

  private static func savedFiles(
    for pasteboard: NSPasteboard,
    changeCount: Int,
    in dropsDirectory: URL,
  ) -> [URL]? {
    guard let lastSaved, lastSaved.pasteboard == pasteboard.name,
      lastSaved.changeCount == changeCount, lastSaved.dropsDirectory == dropsDirectory,
      lastSaved.files.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) })
    else { return nil }
    return lastSaved.files
  }

  /// In the first kept format the item names, its owner's own order.
  private static func image(in item: NSPasteboardItem) -> (data: Data, pathExtension: String)? {
    for type in item.types {
      guard let format = formatsKept.first(where: { $0.type == type }) else { continue }
      if let data = item.data(forType: type) { return (data, format.pathExtension) }
    }
    guard let tiff = item.data(forType: .tiff),
      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    else { return nil }
    return (png, "png")
  }
}

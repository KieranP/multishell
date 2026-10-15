import Foundation
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyLinkRuleTests {
  private func machOExecutable(at url: URL) throws -> URL {
    try Data([0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01]).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  private func opening(
    _ text: String,
    in directory: URL = URL(filePath: "/"),
  ) -> GhosttyLinkRule.Opening? {
    GhosttyLinkRule.opening(for: text, in: directory)
  }

  @Test func aWebLinkOpensOnlyWithAHost() throws {
    let page = try #require(URL(string: "https://example.com/a?b=1"))
    let upperCaseScheme = try #require(URL(string: "HTTP://example.com"))
    #expect(opening(page.absoluteString) == .inDefaultApplication(page))
    #expect(opening(upperCaseScheme.absoluteString) == .inDefaultApplication(upperCaseScheme))
    #expect(opening("https:relative") == nil)
  }

  @Test func aMailLinkOpensOnlyWithAnAddress() throws {
    let mail = try #require(URL(string: "mailto:a@example.com"))
    let addressedInItsQuery = try #require(URL(string: "mailto:?to=a@example.com&subject=x"))
    #expect(opening(mail.absoluteString) == .inDefaultApplication(mail))
    #expect(
      opening(addressedInItsQuery.absoluteString) == .inDefaultApplication(addressedInItsQuery)
    )
    #expect(opening("mailto:") == nil)
    #expect(opening("mailto:?subject=x") == nil)
  }

  @Test func anotherSchemeIsRefused() {
    #expect(opening("vscode://file/tmp/x") == nil)
    #expect(opening("x-apple.systempreferences:com.apple.preference") == nil)
  }

  @Test func aLinkWithCharactersThatCanDisguiseItIsRefused() {
    #expect(opening("https://exa\u{202E}lpmaxe.com") == nil)
    #expect(opening("https://example.com\n") == nil)
    #expect(opening("https://exa\u{200B}mple.com") == nil)
    #expect(opening("https://exa\u{00AD}mple.com") == nil, "a soft hyphen")
    #expect(opening("https://exa\u{FE0F}mple.com") == nil, "a variation selector")
    #expect(opening("https://exa\u{3164}mple.com") == nil, "a Hangul filler")
    #expect(opening("https://exa\u{E0041}mple.com") == nil, "a tag")
    #expect(opening("") == nil)
  }

  @Test func theEditorIsHandedTheNameThePanePrinted() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)
    let symlink = directory.appendingPathComponent("symlink.txt")
    try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: document)

    #expect(opening(document.absoluteString) == .inEditor(URL(filePath: document.path)))
    #expect(opening(document.path) == .inEditor(URL(filePath: document.path)))
    #expect(opening(symlink.path) == .inEditor(URL(filePath: symlink.path)))
  }

  @Test func aPathClimbingWithDotDotIsHandedOverResolved() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)
    try FileManager.default.createDirectory(
      at: directory.appendingPathComponent("sub"),
      withIntermediateDirectories: false,
    )
    let resolved = try #require(Scratch.physicalPath(of: document))

    #expect(opening(directory.path + "/sub/../notes.txt") == .inEditor(URL(filePath: resolved)))
  }

  @Test func aLinkIsJudgedByWhatItsNameResolvesTo() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let executable = try machOExecutable(at: directory.appendingPathComponent("tool"))
    let disguised = directory.appendingPathComponent("readme.pdf")
    try FileManager.default.createSymbolicLink(at: disguised, withDestinationURL: executable)

    #expect(opening(disguised.path) == nil)
  }

  @Test func aFolderOpens() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let resolved = try #require(Scratch.physicalPath(of: directory))
    #expect(opening(directory.path) == .inDefaultApplication(URL(filePath: resolved)))
    #expect(opening("~") != nil)
  }

  @Test func aTextFileOpensInTheEditorWhateverItsMode() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let texts = ["run.py": "print(1)", "app.js": "1", "run.command": "true", "notes.md": "# a"]
    var files = try texts.map { name, contents in
      let file = directory.appendingPathComponent(name)
      try contents.write(to: file, atomically: true, encoding: .utf8)
      return file
    }
    files.append(try Scratch.script("true", at: directory.appendingPathComponent("deploy.sh")))

    for url in files {
      #expect(opening(url.path) == .inEditor(URL(filePath: url.path)), "\(url.lastPathComponent)")
    }
  }

  @Test func aFileThatIsNotTextOpensInItsDefaultApp() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let report = directory.appendingPathComponent("report.pdf")
    try Data("%PDF-1.4\n%".utf8 + [0xE2, 0xE3, 0xCF, 0xD3, 0x0A]).write(to: report)
    let resolved = try #require(Scratch.physicalPath(of: report))

    #expect(opening(report.path) == .inDefaultApplication(URL(filePath: resolved)))
  }

  @Test func anImageOpensInItsDefaultApp() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let image = directory.appendingPathComponent("icon.png")
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
    let resolved = try #require(Scratch.physicalPath(of: image))

    #expect(opening(image.path) == .inDefaultApplication(URL(filePath: resolved)))
  }

  @Test func anArchiveOrOfficeDocumentOpensInItsDefaultApp() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let names = [
      "source.zip", "logs.tar.gz", "build.tgz", "dump.tar", "backup.7z", "notes.docx",
      "old.doc", "draft.odt", "letter.pages", "sheet.xlsx", "budget.numbers",
      "deck.pptx", "talk.key",
    ]
    for name in names {
      let file = directory.appendingPathComponent(name)
      try Data([0]).write(to: file)
      let resolved = try #require(Scratch.physicalPath(of: file))
      #expect(opening(file.path) == .inDefaultApplication(URL(filePath: resolved)), "\(name)")
    }
  }

  /// Archives and an Office file too, but each mounts, installs or runs what it holds.
  @Test func aFileOfAnyOtherKindIsRefused() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let names = [
      "Flow.shortcut", "disk.dmg", "image.iso", "setup.pkg", "app.jar", "macros.docm",
      "page.webarchive", "Additions.osax",
    ]
    for name in names {
      let file = directory.appendingPathComponent(name)
      try Data([0]).write(to: file)
      #expect(opening(file.path) == nil, "\(name)")
    }
  }

  @Test func aFileThatMayLaunchSomethingIsRefusedWhateverItsMode() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let executable = try machOExecutable(at: directory.appendingPathComponent("tool"))
    let installer = directory.appendingPathComponent("setup.pkg")
    try Data("xar!".utf8 + [0x00, 0x1C, 0x00, 0x01]).write(to: installer)
    let bundles = try ["Thing.app", "Helper.prefPane", "Dream.saver", "Extra.plugin"].map { name in
      let bundle = directory.appendingPathComponent(name)
      try FileManager.default.createDirectory(
        at: bundle.appendingPathComponent("Contents/MacOS"),
        withIntermediateDirectories: true,
      )
      return bundle
    }

    for url in [executable, installer] + bundles {
      #expect(opening(url.path) == nil, "\(url.lastPathComponent)")
      #expect(opening(url.absoluteString) == nil, "\(url.lastPathComponent)")
    }
    #expect(opening("file:///System/Applications/Calculator.app") == nil)
  }

  @Test func aFinderAliasOrLocationFileNeverReachesWhatItNames() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let calculator = URL(filePath: "/System/Applications/Calculator.app")
    let alias = directory.appendingPathComponent("notes")
    try URL.writeBookmarkData(
      calculator.bookmarkData(options: .suitableForBookmarkFile),
      to: alias,
    )
    func location(
      _ name: String,
      _ format: PropertyListSerialization.PropertyListFormat,
    ) throws
      -> URL
    {
      let file = directory.appendingPathComponent(name)
      try PropertyListSerialization.data(
        fromPropertyList: ["URL": calculator.absoluteString],
        format: format,
        options: 0,
      )
      .write(to: file)
      return file
    }
    let binaryLocation = try location("binary.fileloc", .binary)
    let textLocation = try location("text.fileloc", .xml)

    #expect(opening(alias.path) == nil)
    #expect(opening(binaryLocation.path) == nil)
    #expect(opening(textLocation.path) == .inEditor(URL(filePath: textLocation.path)))
  }

  @Test func aSourceFileMacOSHasNoTextTypeForOpensInTheEditor() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let sources = [
      "main.rs": "fn main() {}", "main.go": "package main", "index.ts": "export {}",
      "Dockerfile": "FROM scratch", ".gitignore": "build/", "build.zig": "const std = 1;",
      "empty.conf": "",
    ]
    for (name, contents) in sources {
      let file = directory.appendingPathComponent(name)
      try contents.write(to: file, atomically: true, encoding: .utf8)
      #expect(opening(file.path) == .inEditor(URL(filePath: file.path)), "\(name)")
    }
  }

  @Test func aBinaryFileIsJudgedByItsKindNotReadAsText() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let video = directory.appendingPathComponent("clip.ts")
    try Data([0x47, 0x40, 0x00, 0x10]).write(to: video)
    let blob = directory.appendingPathComponent("blob.bin")
    try Data([0x00, 0xFF, 0x00]).write(to: blob)
    let resolvedVideo = try #require(Scratch.physicalPath(of: video))

    #expect(opening(video.path) == .inDefaultApplication(URL(filePath: resolvedVideo)))
    #expect(opening(blob.path) == nil)
  }

  @Test func aPathThatIsMissingOrOnAnotherHostIsRefused() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)

    #expect(opening(directory.appendingPathComponent("gone.txt").path) == nil)
    #expect(opening("file://server" + document.path) == nil)
    #expect(opening("file:notes.txt", in: directory) == nil, "a relative file URL names no file")
  }

  /// GNU `ls --hyperlink` and `rg` name the Mac they ran on.
  @Test func aFileURLNamingThisMacOpens() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)
    var name = [CChar](repeating: 0, count: 256)
    try #require(gethostname(&name, name.count) == 0)
    let hostName = String(
      decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)),
      as: UTF8.self,
    )

    #expect(
      opening("file://\(hostName)\(document.path)") == .inEditor(URL(filePath: document.path))
    )
  }

  @Test func aFileLinkWithAFragmentOrToADeviceIsRefused() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)

    #expect(opening(document.absoluteString + "#top") == nil)
    #expect(opening(document.absoluteString + "?raw=1") == nil)
    #expect(opening("/dev/null") == nil)
  }

  @Test func anOsc8HyperlinkOpensOnlyAFileOnThisMac() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let document = directory.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)

    #expect(
      GhosttyLinkRule.opening(forHyperlink: document.absoluteString, in: directory)
        == .inEditor(URL(filePath: document.path))
    )
    #expect(GhosttyLinkRule.opening(forHyperlink: "https://example.com", in: directory) == nil)
    #expect(GhosttyLinkRule.opening(forHyperlink: "mailto:a@example.com", in: directory) == nil)
    #expect(GhosttyLinkRule.opening(forHyperlink: "notes.txt", in: directory) == nil)
  }

  @Test func aRelativeLinkReachesTheEditorByTheNameItWasFoundUnder() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let sub = directory.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: false)
    let document = sub.appendingPathComponent("notes.txt")
    try "notes".write(to: document, atomically: true, encoding: .utf8)
    let resolved = try #require(Scratch.physicalPath(of: document))

    #expect(opening("sub/notes.txt", in: directory) == .inEditor(URL(filePath: document.path)))
    #expect(opening("./sub/notes.txt", in: directory) == .inEditor(URL(filePath: document.path)))
    #expect(opening("../sub/notes.txt", in: sub) == .inEditor(URL(filePath: resolved)))
  }

  @Test func aFileURLsLineAndColumnAreDroppedToFindTheFile() throws {
    let directory = try Scratch.directory("link")
    defer { Scratch.remove(directory) }
    let source = directory.appendingPathComponent("A.swift")
    try "let a = 1".write(to: source, atomically: true, encoding: .utf8)

    #expect(opening(source.absoluteString + ":12:5") == .inEditor(URL(filePath: source.path)))
  }
}

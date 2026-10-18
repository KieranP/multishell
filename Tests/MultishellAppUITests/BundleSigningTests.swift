import Foundation
import TestScratch
import Testing

/// `sign` in `Scripts/build-lib.sh`, run as `make-app.sh` runs it, on a scratch bundle.
@Suite
struct BundleSigningTests {
  @Test func aBundleWhoseExecutableIsMissingIsRefusedRatherThanSigned() throws {
    let root = try Scratch.directory("signing")
    defer { Scratch.remove(root) }
    let app = try bundle(in: root)

    let result = try sign(app, home: root)

    #expect(result.status != 0)
    #expect(result.standardError.contains("Contents/MacOS/Probe"), "\(result.standardError)")
  }

  @Test func aBundleHoldingItsExecutableIsSigned() throws {
    let root = try Scratch.directory("signing")
    defer { Scratch.remove(root) }
    let app = try bundle(in: root)
    try FileManager.default.copyItem(
      at: URL(fileURLWithPath: "/usr/bin/true"),
      to: app.appendingPathComponent("Contents/MacOS/Probe"),
    )

    let result = try sign(app, home: root)

    #expect(result.status == 0, "\(result.standardError)")
  }

  private func bundle(in root: URL) throws -> URL {
    let app = root.appendingPathComponent("Probe.app", isDirectory: true)
    let contents = app.appendingPathComponent("Contents", isDirectory: true)
    try FileManager.default.createDirectory(
      at: contents.appendingPathComponent("MacOS"),
      withIntermediateDirectories: true,
    )
    let infoPlist = try PropertyListSerialization.data(
      fromPropertyList: [
        "CFBundleExecutable": "Probe",
        "CFBundleIdentifier": "io.multishell.signing-probe",
        "CFBundlePackageType": "APPL",
      ],
      format: .xml,
      options: 0,
    )
    try infoPlist.write(to: contents.appendingPathComponent("Info.plist"))
    return app
  }

  private func sign(_ app: URL, home: URL) throws -> (status: Int32, standardError: String) {
    let library = SourceRoot.url.appendingPathComponent("Scripts/build-lib.sh")
    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/bash")
    shell.arguments = [
      "-c", #"set -euo pipefail; source "$1"; sign - "$2""#, "bash", library.path, app.path,
    ]
    shell.environment = Scratch.bareShellEnvironment(home: home)
    let errors = Pipe()
    shell.standardError = errors
    shell.standardOutput = FileHandle.nullDevice
    try shell.run()
    let standardError = errors.fileHandleForReading.readDataToEndOfFile()
    shell.waitUntilExit()
    return (shell.terminationStatus, String(decoding: standardError, as: UTF8.self))
  }
}

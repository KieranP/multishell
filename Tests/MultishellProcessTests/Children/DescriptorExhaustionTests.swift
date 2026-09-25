import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

/// Lowering the process-wide descriptor limit starves other suites, so this runs only with
/// `MULTISHELL_EXHAUST_DESCRIPTORS=1 swift test --filter DescriptorExhaustionTests`.
@Suite(.serialized)
struct DescriptorExhaustionTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["MULTISHELL_EXHAUST_DESCRIPTORS"] != nil))
  func atTheDescriptorLimitARunThrowsInsteadOfReadingTheAppsStdin() async throws {
    let cwd = URL(fileURLWithPath: NSTemporaryDirectory())
    try await withFreeDescriptors(0) {
      do {
        let output = try await ProcessRunner().capture(
          URL(fileURLWithPath: "/bin/sh"), ["-c", "printf real"], in: cwd)
        Issue.record("ran with output \(output.standardOutput.debugDescription) at the limit")
      } catch is DescriptorUnavailable {
      } catch {
        Issue.record("wrong error: \(error)")
      }
    }
    let output = try await ProcessRunner().run(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd)
    #expect(output == "ok", "works again once descriptors are back")
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["MULTISHELL_EXHAUST_DESCRIPTORS"] != nil))
  func aRunWithRoomForItsPipesButNotStdinThrowsRatherThanTrapping() async throws {
    try await withFreeDescriptors(4) {
      await #expect(throws: (any Error).self) {
        try await ProcessRunner().capture(
          URL(fileURLWithPath: "/bin/sh"), ["-c", "printf real"],
          in: URL(fileURLWithPath: NSTemporaryDirectory()))
      }
    }
  }

  @Test(.enabled(if: ProcessInfo.processInfo.environment["MULTISHELL_EXHAUST_DESCRIPTORS"] != nil))
  func aLaunchWithOneDescriptorLeftReturnsOrThrowsRatherThanTrapping() async throws {
    try await withFreeDescriptors(1) {
      _ = try? await ShellCommand.launch(
        "true", in: URL(fileURLWithPath: NSTemporaryDirectory()), shellPath: "/bin/sh")
    }
  }

  private func withFreeDescriptors(_ free: Int, _ body: () async throws -> Void) async throws {
    // libdispatch raises the soft limit the first time a process creates a file source, so
    // do it now rather than inside the runner, where it would undo the shortage.
    let warmUp = FileHandle(fileDescriptor: 2, closeOnDealloc: false)
    warmUp.readabilityHandler = { _ in }
    warmUp.readabilityHandler = nil

    var saved = rlimit()
    getrlimit(RLIMIT_NOFILE, &saved)
    var held: [Int32] = []
    defer {
      var restore = saved
      setrlimit(RLIMIT_NOFILE, &restore)
      for fd in held { close(fd) }
    }

    let inUse = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    var lowered = saved
    lowered.rlim_cur = rlim_t(inUse + 8)
    try #require(setrlimit(RLIMIT_NOFILE, &lowered) == 0)
    while true {
      let fd = open("/dev/null", O_RDONLY)
      if fd < 0 { break }
      held.append(fd)
    }
    try #require(held.count >= free, "the limit left no room to free \(free)")
    for fd in held.suffix(free) { close(fd) }
    held.removeLast(min(free, held.count))

    try await body()
  }
}

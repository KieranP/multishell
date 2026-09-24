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

    // Take every descriptor up to a limit just above what is open now.
    let inUse = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    var lowered = saved
    lowered.rlim_cur = rlim_t(inUse + 8)
    #expect(setrlimit(RLIMIT_NOFILE, &lowered) == 0)
    while true {
      let fd = open("/dev/null", O_RDONLY)
      if fd < 0 { break }
      held.append(fd)
    }

    let runner = ProcessRunner()
    let cwd = URL(fileURLWithPath: NSTemporaryDirectory())
    do {
      let output = try await runner.capture(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "printf real"], in: cwd)
      Issue.record("ran with output \(output.standardOutput.debugDescription) at the limit")
    } catch is PipeUnavailable {
      // What we want: a loud failure the caller reports.
    } catch {
      Issue.record("wrong error: \(error)")
    }

    var restore = saved
    setrlimit(RLIMIT_NOFILE, &restore)
    for fd in held { close(fd) }
    held = []
    let output = try await runner.run(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd)
    #expect(output == "ok", "works again once descriptors are back")
  }
}

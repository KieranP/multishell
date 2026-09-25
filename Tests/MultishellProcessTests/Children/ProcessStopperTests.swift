import Foundation
import Testing

@testable import MultishellProcess

/// Past macOS's PID_MAX of 99999. waitid answers it as it does a reaped child,
/// and a reaped child's own pid can go to a child another test starts meanwhile.
private let pidNoProcessHolds: pid_t = 100_000

/// The timeout and the user's stop both go through `ProcessStopper`, so both must end an
/// interactive shell, which ignores SIGTERM, and the command it is running.
@Suite
struct ProcessStopperTests {
  private let runner = ProcessRunner()
  private let cwd = URL(fileURLWithPath: NSTemporaryDirectory())

  /// The pid of the `sleep` the shell runs, so the test can check it went
  /// with the shell rather than living on as an orphan.
  private func sleepPID(in output: String) -> pid_t? {
    output.split(whereSeparator: \.isNewline).first.flatMap { Int32($0) }
  }

  /// `kill(pid, 0)` calls a zombie alive and launchd reaps orphans at its own pace, so a
  /// zombie counts as ended and the check waits a little.
  private func hasEnded(_ pid: pid_t, polls: Int = 30) async -> Bool {
    for _ in 0..<polls {
      if kill(pid, 0) != 0 || isZombie(pid) { return true }
      try? await Task.sleep(for: .milliseconds(100))
    }
    return false
  }

  private func isZombie(_ pid: pid_t) -> Bool {
    KernelProcessTable.record(of: pid).map { Int32($0.kp_proc.p_stat) == SZOMB } ?? false
  }

  private func spawnExitingChild() throws -> pid_t {
    var pid: pid_t = 0
    let argv: [UnsafeMutablePointer<CChar>?] = [strdup("/usr/bin/true"), nil]
    defer { for argument in argv { free(argument) } }
    try #require(posix_spawn(&pid, "/usr/bin/true", nil, nil, argv, environ) == 0)
    return pid
  }

  @Test func aStopReachingAnExitedChildNotYetMarkedSignalsNothing() throws {
    let pid = try spawnExitingChild()
    var info = siginfo_t()
    waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT)
    defer { waitpid(pid, nil, 0) }
    let child = RunningChild()
    child.started(pid)
    let stopper = ProcessStopper()
    stopper.attach(child)

    stopper.stop(.timedOut(after: .milliseconds(1)))
    #expect(stopper.reason == nil)
    #expect(!child.isRunning)
  }

  @Test func aStopReachingAReapedChildNotYetMarkedSignalsNothing() {
    let child = RunningChild()
    child.started(pidNoProcessHolds)
    let stopper = ProcessStopper()
    stopper.attach(child)

    stopper.stop()
    #expect(stopper.reason == nil)
    #expect(!child.isRunning)
  }

  @Test func aStopAskedBeforeAChildThatExitedFirstIsAttachedStopsThatRun() throws {
    let pid = try spawnExitingChild()
    var info = siginfo_t()
    waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT)
    defer { waitpid(pid, nil, 0) }
    let child = RunningChild()
    child.started(pid)
    let stopper = ProcessStopper()
    stopper.stop()

    stopper.attach(child)

    #expect(stopper.reason == .byUser)
  }

  @Test func aTimeoutEndsAnInteractiveShellAndTheCommandItRuns() async throws {
    for shell in ["/bin/zsh", "/bin/bash"]
    where FileManager.default.isExecutableFile(atPath: shell) {
      let started = ContinuousClock.now
      let output = try await runner.capture(
        URL(fileURLWithPath: shell), ["-i", "-c", "sleep 30 & echo $!; wait"], in: cwd,
        environment: ["HOME": cwd.path, "HISTFILE": ""], timeout: .milliseconds(500))
      let elapsed = ContinuousClock.now - started
      #expect(output.stop == .timedOut(after: .milliseconds(500)), "\(shell)")
      #expect(!output.succeeded, "\(shell)")
      // The child sleeps thirty, so twelve tells a stop from no stop
      // rather than a fast runner from a slow one.
      #expect(elapsed < .seconds(12), "\(shell) took \(elapsed) to be ended")
      let child = try #require(sleepPID(in: output.standardOutput), "\(shell)")
      #expect(await hasEnded(child), "\(shell) left its sleep running as pid \(child)")
    }
  }

  @Test func theStopperEndsTheChildAndSaysTheUserAsked() async throws {
    let stopper = ProcessStopper()
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      stopper.stop()
    }
    let started = ContinuousClock.now
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "sleep 30"], in: cwd, stopper: stopper)
    #expect(output.stop == .byUser)
    #expect(ContinuousClock.now - started < .seconds(12), "the child sleeps thirty")
  }

  @Test func aStopAskedBeforeTheChildStartsAppliesToIt() async throws {
    let stopper = ProcessStopper()
    stopper.stop()
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "sleep 30"], in: cwd, stopper: stopper)
    #expect(output.stop == .byUser)
  }

  /// The status proves the kill, not a clock: a loaded CI runner's startup
  /// stall alone ran past a 12s bound.
  @Test func aChildThatIgnoresSIGHUPIsKilledAfterTheGrace() async throws {
    let started = ContinuousClock.now
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "trap '' HUP; sleep 30"], in: cwd,
      timeout: .milliseconds(200))
    let elapsed = ContinuousClock.now - started
    #expect(output.stop == .timedOut(after: .milliseconds(200)))
    #expect(elapsed > .seconds(2), "the grace was skipped: \(elapsed)")
    #expect(output.status == SIGKILL, "the kill never came: exit status \(output.status)")
  }

  @Test func aChildThatFinishesInTimeHasNoStop() async throws {
    let stopper = ProcessStopper()
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd, timeout: .seconds(5),
      stopper: stopper)
    #expect(output.stop == nil && output.succeeded)
    #expect(stopper.reason == nil)
  }

  /// `WorktreeCoordinator.remove` gives one stopper to both delete hooks; a Cancel between
  /// them used to leave the second running unsignalled while the run read as stopped.
  @Test func aStopBetweenTwoChildrenCarriesToTheSecondRatherThanPoisoning() async throws {
    let stopper = ProcessStopper()
    let first = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd, stopper: stopper)
    #expect(first.succeeded)

    stopper.stop()
    #expect(stopper.reason == nil, "nothing was signalled: the first child had already exited")
    #expect(stopper.isStopped, "but the ask stands for whatever runs next")

    let started = ContinuousClock.now
    let second = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "sleep 30"], in: cwd, stopper: stopper)
    #expect(second.stop == .byUser, "the second hook is the one the Cancel was for")
    #expect(ContinuousClock.now - started < .seconds(12), "it slept its thirty")
  }

  /// The timer is armed per child, so a timeout firing as its child exits must not carry
  /// on and end the next hook, a live child nobody asked to stop.
  @Test func aTimeoutThatMissesItsChildDoesNotEndTheNextOne() async throws {
    let stopper = ProcessStopper()
    let first = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd, stopper: stopper)
    #expect(first.succeeded)

    // The race, run outright: the child is gone, and its timer fires anyway.
    stopper.stop(.timedOut(after: .milliseconds(1)))
    #expect(stopper.reason == nil)
    #expect(!stopper.isStopped, "a timeout dies with the run that armed it")

    let second = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf two"], in: cwd, stopper: stopper)
    #expect(second.stop == nil && second.standardOutput == "two")
  }

  /// SIGHUP reaches the group, so the shell goes at once and the guard on it
  /// let a grandchild that traps SIGHUP run until the user logged out.
  @Test func aGrandchildThatTrapsSIGHUPIsKilledThoughTheShellWentAtOnce() async throws {
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"),
      ["-c", "/bin/sh -c \"trap '' HUP; sleep 30\" & echo $!; wait"], in: cwd,
      timeout: .milliseconds(200))
    let child = try #require(sleepPID(in: output.standardOutput))
    #expect(await hasEnded(child), "left running as pid \(child)")
  }

  /// Every member left is younger than the hangup, as a stranger's group is,
  /// but the group's leader is gone rather than young.
  @Test func aChildTheHangupItselfStartedIsKilledAfterTheGrace() async throws {
    let output = try await runner.capture(
      URL(fileURLWithPath: "/bin/sh"),
      [
        "-c",
        "trap 'sleep 30 </dev/null >/dev/null 2>&1 & echo $!; exit 0' HUP; "
          + "while :; do sleep 0.05; done",
      ], in: cwd, timeout: .milliseconds(200))
    let child = try #require(sleepPID(in: output.standardOutput))
    let polls = Int(ProcessStopper.killGrace * 10) + 50
    #expect(await hasEnded(child, polls: polls), "left running as pid \(child)")
  }

  @Test func aStoppedScriptIsAFailureThatSaysSo() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    do {
      _ = try await ShellCommand.runScript(
        "sleep 30", in: shell.home, environment: shell.environment, shellPath: shell.path,
        timeout: .milliseconds(300))
      Issue.record("the script did not fail")
    } catch let failure as ProcessFailure {
      #expect(failure.stop == .timedOut(after: .milliseconds(300)))
    }
  }
}

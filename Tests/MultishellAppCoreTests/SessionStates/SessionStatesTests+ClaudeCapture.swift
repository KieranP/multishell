import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

extension SessionStatesTests {
  @Test func claudesCapturedFanOutNeverDropsListedWorkOrLosesALauncher() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    for (index, line) in ClaudeHookCapture.fanOut.enumerated() {
      try replay.feed(line, for: .session(a))
      let workers = replay.states.workers(.session(a))
      let onRoster = Dictionary(workers.map { ($0.id, $0) }) { first, _ in first }
      #expect(
        replay.lastListedIDs.isSubset(of: onRoster.keys),
        "event \(index): listed but missing \(replay.lastListedIDs.subtracting(onRoster.keys))")
      for (child, launcher) in replay.launcherByWorkerID {
        guard let worker = onRoster[child], onRoster[launcher] != nil else { continue }
        #expect(worker.parentID == launcher, "event \(index): \(child) not under \(launcher)")
      }
      #expect(workers.allSatisfy { $0.occurrences == 1 }, "event \(index): a resume counted twice")
      #expect(!workers.contains { $0.hasFailed }, "event \(index): nothing here was killed")
    }
    #expect(workersOut(replay.states).isEmpty)
    #expect(replay.states[.session(a)] == .done)
  }

  @Test func claudesCapturedKillsTurnOnlyTheKilledWorkersAndTheirShellsFailed() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let killed: Set<String> = ["paused-victim", "busy-victim", "b3udsevyd"]
    var failedSeen: Set<String> = []
    let lastStop = try #require(
      ClaudeHookCapture.killsAndChains.lastIndex { $0.contains(#""hook_event_name":"Stop""#) })
    for (index, line) in ClaudeHookCapture.killsAndChains[...lastStop].enumerated() {
      try replay.feed(line, for: .session(a))
      let workers = replay.states.workers(.session(a))
      let onRoster = Set(workers.map(\.id))
      #expect(
        replay.lastListedIDs.isSubset(of: onRoster),
        "event \(index): listed but missing \(replay.lastListedIDs.subtracting(onRoster))")
      for worker in workers where worker.hasFailed {
        let name = worker.description ?? worker.id
        #expect(killed.contains(name), "event \(index): \(name) drawn failed")
        failedSeen.insert(name)
      }
    }
    #expect(failedSeen == killed)
    #expect(replay.states[.session(a)] == .done)
    #expect(Set(replay.states.workers(.session(a)).map { $0.description ?? $0.id }) == killed)
  }

  @Test func claudesCapturedChainStaysNestedUnderParentsThatHandedBack() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let chainThreeLaunched = try #require(
      ClaudeHookCapture.killsAndChains.firstIndex { $0.contains("abb8e1ca3cb19e05f") })
    for line in ClaudeHookCapture.killsAndChains[...(chainThreeLaunched + 1)] {
      try replay.feed(line, for: .session(a))
    }
    let drawn = replay.states.workers(.session(a)).nested
      .map { "\(String(repeating: "  ", count: $0.depth))\($0.worker.description ?? $0.id)" }
    #expect(
      drawn.contains("chain-1") && drawn.contains("  chain-2") && drawn.contains("    chain-3"))
    #expect(drawn.contains("shell-leaver") && drawn.contains("  b09wzp9ad"))
  }

  @Test func claudesCapturedFanOutDrawsEachWorkerUnderItsLauncherMidRun() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let firstPhantomStop = try #require(
      ClaudeHookCapture.fanOut.firstIndex { $0.contains("a54f52491c72bb5d4") })
    for line in ClaudeHookCapture.fanOut[...firstPhantomStop] {
      try replay.feed(line, for: .session(a))
    }
    let drawn = replay.states.workers(.session(a)).nested
      .map { "\(String(repeating: "  ", count: $0.depth))\($0.worker.description ?? $0.id)" }
    #expect(
      drawn == [
        "short-parent", "  long-child", "outer", "  inner-2", "    b0fcq54hb", "  inner-1",
        "    bcdy37379", "victim", "b25al8j9c",
      ], "short-parent has ended but holds long-child; siblings in the order heard")
  }

  @Test func claudesCapturedTaskStopTurnsTheParentAndWhatItHeldFailed() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let twoWaitsHandedBack = try #require(
      ClaudeHookCapture.killedParent.firstIndex {
        $0.contains(#""hook_event_name":"PostToolUse""#)
          && $0.contains(#""agent_id":"aac8aafe04779d061""#)
          && $0.contains(#""tool_name":"SubagentHandback""#)
      })
    var failedSeen: Set<String> = []
    for (index, line) in ClaudeHookCapture.killedParent.enumerated() {
      try replay.feed(line, for: .session(a))
      let workers = replay.states.workers(.session(a))
      let onRoster = Set(workers.map(\.id))
      #expect(
        replay.lastListedIDs.isSubset(of: onRoster),
        "event \(index): listed but missing \(replay.lastListedIDs.subtracting(onRoster))")
      if (10...twoWaitsHandedBack).contains(index) {
        #expect(onRoster.contains("aac8aafe04779d061"), "event \(index): two-waits missing")
      }
      for worker in workers where worker.hasFailed && worker.description != nil {
        failedSeen.insert(worker.description ?? "")
      }
    }
    #expect(failedSeen == ["doomed-parent", "doomed-child", "two-waits"])
  }

  @Test func claudesCapturedMidChainKillLeavesTheTopOutWithTheKilledUnderIt() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let top = "aadf87884f3bd3b86"
    let topHandedBack = try #require(
      ClaudeHookCapture.killedMiddle.firstIndex {
        $0.contains(#""hook_event_name":"PostToolUse""#) && $0.contains(#""agent_id":"\#(top)""#)
          && $0.contains(#""tool_name":"SubagentHandback""#)
      })
    let killed: Set<String> = ["middle", "leaf", "waiter", "list-victim"]
    var failedSeen: Set<String> = []
    var middleSeenUnderTop = false
    for (index, line) in ClaudeHookCapture.killedMiddle.enumerated() {
      try replay.feed(line, for: .session(a))
      let workers = replay.states.workers(.session(a))
      let onRoster = Set(workers.map(\.id))
      #expect(
        replay.lastListedIDs.isSubset(of: onRoster),
        "event \(index): listed but missing \(replay.lastListedIDs.subtracting(onRoster))")
      if (8...topHandedBack).contains(index) {
        #expect(onRoster.contains(top), "event \(index): top missing")
      }
      for worker in workers where worker.hasFailed {
        guard let name = worker.description else { continue }
        #expect(killed.contains(name), "event \(index): \(name) drawn failed")
        failedSeen.insert(name)
      }
      let drawn = workers.nested.map { ($0.worker.description, $0.depth, $0.worker.hasFailed) }
      if drawn.contains(where: { $0.0 == "middle" && $0.1 == 1 && $0.2 }),
        drawn.contains(where: { $0.0 == "leaf" && $0.1 == 2 && $0.2 })
      {
        middleSeenUnderTop = true
      }
    }
    #expect(failedSeen == killed)
    #expect(middleSeenUnderTop, "the killed middle and leaf drawn failed under top")
  }

  @Test func claudesCapturedEscOnTheAgentEndsNoWorkerItHadOut() throws {
    var replay = try ClaudeHookReplay()
    defer { Scratch.remove(replay.directory) }
    let payloads = ClaudeHookCapture.mainInterrupted
    let workers = [
      "a016787520450c970", "a502d28281e37813e", "a0ae5dc453dd75eb6", "a6d07f6e138030eec",
    ]
    let handBacks = try workers.map { id in
      try #require(
        payloads.firstIndex {
          $0.contains(#""hook_event_name":"PostToolUse""#) && $0.contains(#""agent_id":"\#(id)""#)
            && $0.contains(#""tool_name":"SubagentHandback""#)
        })
    }
    let launches = try workers.map { id in
      try #require(payloads.firstIndex { $0.contains(#""agentId":"\#(id)""#) })
    }
    for (index, line) in payloads.enumerated() {
      try replay.feed(line, for: .session(a))
      let current = replay.states.workers(.session(a))
      let onRoster = Set(current.map(\.id))
      #expect(
        replay.lastListedIDs.isSubset(of: onRoster),
        "event \(index): listed but missing \(replay.lastListedIDs.subtracting(onRoster))")
      for (offset, id) in workers.enumerated()
      where (launches[offset]...handBacks[offset]).contains(index) {
        #expect(onRoster.contains(id), "event \(index): \(id) missing")
      }
      #expect(!current.contains { $0.hasFailed }, "event \(index): nothing here was killed")
    }
    #expect(replay.states[.session(a)] == .done)
  }
}

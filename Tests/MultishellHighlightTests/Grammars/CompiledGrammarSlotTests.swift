import Dispatch
import MultishellAppCore
import Synchronization
import Testing

@testable import MultishellHighlight

@Suite
struct CompiledGrammarSlotTests {
  private final class SecondCaller: Sendable {
    let compiles = Mutex(0)
    let result = Mutex<CompiledGrammar?>(nil)
    let waits = DispatchSemaphore(value: 0)
    let finished = DispatchGroup()
  }

  private static func startSecondCallerAndAwaitItsWaitOrCompile(
    in slot: CompiledGrammarSlot,
    second: SecondCaller,
    secondCompile: CompiledGrammar,
  ) {
    DispatchQueue.global().async(group: second.finished) {
      let compiled = slot.grammar {
        second.compiles.withLock { $0 += 1 }
        second.waits.signal()
        return secondCompile
      }
      second.result.withLock { $0 = compiled }
    }
    second.waits.wait()
  }

  @Test func aCallerArrivingMidCompileWaitsForItRatherThanCompilingAgain() throws {
    let grammar = try HighlightGrammars.compile(.json)
    let second = SecondCaller()
    let slot = CompiledGrammarSlot { second.waits.signal() }

    let first = slot.grammar {
      Self.startSecondCallerAndAwaitItsWaitOrCompile(
        in: slot,
        second: second,
        secondCompile: grammar,
      )
      return grammar
    }
    second.finished.wait()

    #expect(first != nil)
    #expect(second.result.withLock { $0 } != nil)
    #expect(second.compiles.withLock { $0 } == 0)
  }

  @Test func aCallerWaitingOnACompileThatFailsCompilesItItself() throws {
    let grammar = try HighlightGrammars.compile(.json)
    let second = SecondCaller()
    let slot = CompiledGrammarSlot { second.waits.signal() }

    let first = slot.grammar {
      Self.startSecondCallerAndAwaitItsWaitOrCompile(
        in: slot,
        second: second,
        secondCompile: grammar,
      )
      return nil
    }
    second.finished.wait()

    #expect(first == nil)
    #expect(second.result.withLock { $0 } != nil)
    #expect(second.compiles.withLock { $0 } == 1)
  }
}

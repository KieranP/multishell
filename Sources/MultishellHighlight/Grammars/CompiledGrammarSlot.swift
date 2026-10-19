import Dispatch
import Synchronization

/// One language's grammar, held only once it compiled. A highlight that needs it while
/// another compiles it waits for that one rather than compiling it again.
final class CompiledGrammarSlot: Sendable {
  private enum State {
    case empty
    case compiling(DispatchGroup)
    case compiled(CompiledGrammar)
  }

  private enum Claim {
    case compiled(CompiledGrammar)
    case waitFor(DispatchGroup)
    case compile(DispatchGroup)
  }

  private let state = Mutex(State.empty)
  private let onWillWait: @Sendable () -> Void

  init(onWillWait: @escaping @Sendable () -> Void = {}) {
    self.onWillWait = onWillWait
  }

  /// A compile that fails leaves the slot empty, so the next caller, waiting or not,
  /// compiles it again.
  func grammar(compiling compile: () -> CompiledGrammar?) -> CompiledGrammar? {
    while true {
      switch claim() {
      case .compiled(let grammar):
        return grammar

      case .waitFor(let compiling):
        onWillWait()
        compiling.wait()

      case .compile(let compiling):
        // Outside the lock: about 100 ms is too long for an unfair lock, so waiters wait on
        // the group instead.
        let compiled = compile()
        state.withLock { $0 = compiled.map(State.compiled) ?? .empty }
        compiling.leave()
        return compiled
      }
    }
  }

  private func claim() -> Claim {
    state.withLock { state in
      switch state {
      case .compiled(let grammar):
        return .compiled(grammar)

      case .compiling(let compiling):
        return .waitFor(compiling)

      case .empty:
        let compiling = DispatchGroup()
        compiling.enter()
        state = .compiling(compiling)
        return .compile(compiling)
      }
    }
  }
}

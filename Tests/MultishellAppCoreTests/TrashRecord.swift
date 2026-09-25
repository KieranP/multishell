import Foundation
import MultishellCore
import Synchronization
import TestScratch

/// What the fake Trash was asked, written from whatever thread asked.
final class TrashRecord: Sendable {
  private struct State {
    var destination: URL? = Scratch.path("trash")
    var trashed: [URL] = []
    var onMainThread: [Bool] = []
  }

  private let state = Mutex(State())

  deinit {
    if let destination { Scratch.remove(destination) }
  }

  var destination: URL? {
    get { state.withLock { $0.destination } }
    set { state.withLock { $0.destination = newValue } }
  }
  var trashed: [URL] {
    get { state.withLock { $0.trashed } }
    set { state.withLock { $0.trashed = newValue } }
  }
  var onMainThread: [Bool] {
    get { state.withLock { $0.onMainThread } }
    set { state.withLock { $0.onMainThread = newValue } }
  }
}

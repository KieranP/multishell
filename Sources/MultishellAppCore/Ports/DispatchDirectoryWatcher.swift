import Foundation
import MultishellCore

/// `DirectoryWatcher` on kqueue, Darwin only. Fires on direct children
/// alone, so callers pass every level; coalesced for 400 ms.
@MainActor
public final class DispatchDirectoryWatcher: DirectoryWatcher {
  public var onChange: (@MainActor ([URL]) -> Void)?

  /// The source watching a path, against the directory it was opened on: a
  /// descriptor follows its inode, never its name.
  private struct Watch {
    let source: any DispatchSourceFileSystemObject
    let directory: Identity
  }

  /// What names one directory on one volume, as `fstat` gives it.
  struct Identity: Hashable, Sendable {
    let device: dev_t
    let inode: ino_t

    init?(ofDescriptor descriptor: Int32) {
      self.init { fstat(descriptor, &$0) }
    }

    init?(ofPath path: String) {
      self.init { stat(path, &$0) }
    }

    private init?(reading read: (inout stat) -> Int32) {
      var status = stat()
      guard read(&status) == 0 else { return nil }
      self.device = status.st_dev
      self.inode = status.st_ino
    }
  }

  /// What a scan off the main actor found: which known paths now name
  /// another directory, and a descriptor for each path that needs a source.
  private struct Scan: Sendable {
    var stale: Set<URL> = []
    var opened: [URL: (descriptor: Int32, directory: Identity)] = [:]

    func closeAll() {
      for (descriptor, _) in opened.values { close(descriptor) }
    }
  }

  private var watches: [URL: Watch] = [:]
  private var pending: Task<Void, Never>?
  private var fired: Set<URL> = []
  /// Bumped by every `watch` and `stop`, so a scan that finishes after a
  /// later one arms nothing.
  private var generation = 0
  private let openDirectory: @Sendable (String) -> Int32

  public convenience init() {
    self.init { open($0, O_EVTONLY) }
  }

  init(opening openDirectory: @escaping @Sendable (String) -> Int32) {
    self.openDirectory = openDirectory
  }

  /// The stats and opens run off the main actor: a repository on a stalled
  /// mount would otherwise hold the window until the mount timed out.
  public func watch(_ directories: [URL]) async {
    let wanted = Set(directories.map(\.standardizedFileURL))
    generation += 1
    let generation = generation
    let known = watches.filter { wanted.contains($0.key) }.mapValues(\.directory)
    let openDirectory = openDirectory
    let scan = await offMain { Self.scan(wanted, known: known, opening: openDirectory) }
    guard generation == self.generation else {
      scan.closeAll()
      return
    }
    for (url, watch) in watches where !wanted.contains(url) || scan.stale.contains(url) {
      watch.source.cancel()
      watches[url] = nil
    }
    for (url, opened) in scan.opened {
      watches[url] = makeWatch(for: url, descriptor: opened.descriptor, on: opened.directory)
    }
  }

  /// A known path whose inode moved is stale: `git worktree remove` then
  /// `add` leaves the old source on an inode nothing will touch again.
  private nonisolated static func scan(
    _ wanted: Set<URL>, known: [URL: Identity], opening openDirectory: (String) -> Int32
  ) -> Scan {
    var scan = Scan()
    for url in wanted {
      if let directory = known[url] {
        guard Identity(ofPath: url.path) != directory else { continue }
        scan.stale.insert(url)
      }
      let descriptor = openDirectory(url.path)
      guard descriptor >= 0 else { continue }
      // From the descriptor, not the path: the two could differ in between,
      // and what is watched is whatever was opened.
      guard let directory = Identity(ofDescriptor: descriptor) else {
        close(descriptor)
        continue
      }
      scan.opened[url] = (descriptor, directory)
    }
    return scan
  }

  public func stop() {
    generation += 1
    for watch in watches.values {
      watch.source.cancel()
    }
    watches.removeAll()
    pending?.cancel()
  }

  private func makeWatch(for url: URL, descriptor: Int32, on directory: Identity) -> Watch {
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .rename, .delete],
      queue: .main
    )
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated { self?.coalesce(url) }
    }
    source.setCancelHandler { close(descriptor) }
    source.resume()
    return Watch(source: source, directory: directory)
  }

  private func coalesce(_ url: URL) {
    fired.insert(url)
    pending?.cancel()
    pending = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled, let self else { return }
      let changed = Array(fired)
      fired.removeAll()
      onChange?(changed)
    }
  }
}

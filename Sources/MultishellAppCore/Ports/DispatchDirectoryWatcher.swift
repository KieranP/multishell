#if canImport(Darwin)
  import Foundation
  import MultishellCore

  /// `DirectoryWatcher` on kqueue, Darwin only. Fires on direct children
  /// alone, so callers pass every level; coalesced for 400 ms.
  @MainActor
  public final class DispatchDirectoryWatcher: DirectoryWatcher {
    public var onChange: (@MainActor () -> Void)?

    /// The source watching a path, against the directory it was opened on: a
    /// descriptor follows its inode, never its name.
    private struct Watch {
      let source: any DispatchSourceFileSystemObject
      let directory: Identity
    }

    /// What names one directory on one volume, as `fstat` gives it.
    private struct Identity: Equatable {
      let device: dev_t
      let inode: ino_t

      init?(ofDescriptor descriptor: Int32) {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { return nil }
        self.device = status.st_dev
        self.inode = status.st_ino
      }

      init?(ofPath path: String) {
        var status = stat()
        guard stat(path, &status) == 0 else { return nil }
        self.device = status.st_dev
        self.inode = status.st_ino
      }
    }

    private var watches: [URL: Watch] = [:]
    private var pending: Task<Void, Never>?

    public init() {}

    public func watch(_ directories: [URL]) {
      let wanted = Set(directories.map(\.standardizedFileURL))
      for (url, watch) in watches where !wanted.contains(url) || isStale(watch, at: url) {
        watch.source.cancel()
        watches[url] = nil
      }
      for url in wanted where watches[url] == nil {
        watches[url] = makeWatch(for: url)
      }
    }

    /// Whether the path now names a different directory: `git worktree remove`
    /// then `add` leaves the old source on an inode nothing will touch again.
    private func isStale(_ watch: Watch, at url: URL) -> Bool {
      Identity(ofPath: url.path) != watch.directory
    }

    public func stop() {
      for watch in watches.values {
        watch.source.cancel()
      }
      watches.removeAll()
      pending?.cancel()
    }

    private func makeWatch(for url: URL) -> Watch? {
      let descriptor = open(url.path, O_EVTONLY)
      guard descriptor >= 0 else { return nil }
      // From the descriptor, not the path: the two could differ in between,
      // and what is watched is whatever was opened.
      guard let directory = Identity(ofDescriptor: descriptor) else {
        close(descriptor)
        return nil
      }

      let source = DispatchSource.makeFileSystemObjectSource(
        fileDescriptor: descriptor,
        eventMask: [.write, .rename, .delete],
        queue: .main
      )
      source.setEventHandler { [weak self] in
        MainActor.assumeIsolated { self?.coalesce() }
      }
      source.setCancelHandler { close(descriptor) }
      source.resume()
      return Watch(source: source, directory: directory)
    }

    private func coalesce() {
      pending?.cancel()
      pending = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        self?.onChange?()
      }
    }
  }
#endif

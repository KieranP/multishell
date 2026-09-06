#if canImport(Darwin)
  import Foundation
  import MultishellCore

  /// `DirectoryWatcher` on kqueue via `DispatchSource`. Darwin only: the
  /// vnode source and `O_EVTONLY` have no Linux counterpart, where a
  /// frontend supplies an inotify watcher behind the same port.
  ///
  /// A directory source fires when its direct children change, not deeper,
  /// so callers pass every level they care about. Events are coalesced for
  /// 400 ms because git touches several files per operation.
  @MainActor
  public final class DispatchDirectoryWatcher: DirectoryWatcher {
    public var onChange: (@MainActor () -> Void)?

    private var sources: [URL: any DispatchSourceFileSystemObject] = [:]
    private var pending: Task<Void, Never>?

    public init() {}

    public func watch(_ directories: [URL]) {
      let wanted = Set(directories.map(\.standardizedFileURL))
      for (url, source) in sources where !wanted.contains(url) {
        source.cancel()
        sources[url] = nil
      }
      for url in wanted where sources[url] == nil {
        sources[url] = makeSource(for: url)
      }
    }

    public func stop() {
      for source in sources.values {
        source.cancel()
      }
      sources.removeAll()
      pending?.cancel()
    }

    private func makeSource(for url: URL) -> (any DispatchSourceFileSystemObject)? {
      let descriptor = open(url.path, O_EVTONLY)
      guard descriptor >= 0 else { return nil }

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
      return source
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

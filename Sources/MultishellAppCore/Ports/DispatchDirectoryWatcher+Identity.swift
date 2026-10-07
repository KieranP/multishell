import Foundation

extension DispatchDirectoryWatcher {
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
}

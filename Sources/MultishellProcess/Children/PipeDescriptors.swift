import Foundation
import System

enum PipeDescriptors {
  typealias Ends = (reading: FileHandle, writing: FileDescriptor)

  /// Both ends of a new pipe, or `DescriptorUnavailable`. Not `Pipe()`, which cannot
  /// fail and so returns two handles on descriptor 0 at the limit.
  static func make() throws -> Ends {
    var descriptors: [Int32] = [-1, -1]
    guard pipe(&descriptors) == 0 else { throw DescriptorUnavailable(code: errno) }
    // macOS has no pipe2, so a fork between the two calls still inherits them.
    for descriptor in descriptors { _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC) }
    return (
      FileHandle(fileDescriptor: descriptors[0], closeOnDealloc: true),
      FileDescriptor(rawValue: descriptors[1]),
    )
  }
}

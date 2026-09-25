import Foundation
import System
import Testing

@testable import MultishellProcess

struct DetachedLaunchTests {
  @Test func anOpenNullDeviceIsNotHandedToWhateverElseTheAppStarts() throws {
    let device = try DetachedLaunch.NullDevice()
    defer { device.close() }

    #expect(fcntl(device.descriptor.rawValue, F_GETFD) & FD_CLOEXEC != 0)
  }

  @Test func theRunnersPipesAreNotHandedToWhateverElseTheAppStarts() throws {
    let pipe = try PipeBuffer.makePipe()
    defer {
      try? pipe.reading.close()
      try? pipe.writing.close()
    }

    #expect(fcntl(pipe.reading.fileDescriptor, F_GETFD) & FD_CLOEXEC != 0)
    #expect(fcntl(pipe.writing.rawValue, F_GETFD) & FD_CLOEXEC != 0)
  }
}

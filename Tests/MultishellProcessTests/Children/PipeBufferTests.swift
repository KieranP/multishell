import Foundation
import System
import Testing

@testable import MultishellProcess

struct PipeBufferTests {
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

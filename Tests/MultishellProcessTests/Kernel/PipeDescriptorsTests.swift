import Foundation
import System
import Testing

@testable import MultishellProcess

struct PipeDescriptorsTests {
  @Test func theRunnersPipesAreNotHandedToWhateverElseTheAppStarts() throws {
    let pipe = try PipeDescriptors.make()
    defer {
      try? pipe.reading.close()
      try? pipe.writing.close()
    }

    #expect(fcntl(pipe.reading.fileDescriptor, F_GETFD) & FD_CLOEXEC != 0)
    #expect(fcntl(pipe.writing.rawValue, F_GETFD) & FD_CLOEXEC != 0)
  }
}

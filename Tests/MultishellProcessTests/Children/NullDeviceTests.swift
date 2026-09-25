import Foundation
import System
import Testing

@testable import MultishellProcess

struct NullDeviceTests {
  @Test func anOpenNullDeviceIsNotHandedToWhateverElseTheAppStarts() throws {
    let device = try NullDevice()
    defer { device.close() }

    #expect(fcntl(device.descriptor.rawValue, F_GETFD) & FD_CLOEXEC != 0)
  }
}

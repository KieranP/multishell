import Darwin
import Testing

@testable import MultishellProcess

@Suite
struct TerminalDeviceTests {
  @Test func aDevicePathGivesItsDeviceNumber() {
    var status = stat()
    #expect(stat("/dev/null", &status) == 0)
    #expect(TerminalDevice.number(atPath: "/dev/null") == status.st_rdev)
  }

  @Test func aMissingPathHasNoDeviceNumber() {
    #expect(TerminalDevice.number(atPath: "/dev/no-such-terminal") == nil)
  }
}

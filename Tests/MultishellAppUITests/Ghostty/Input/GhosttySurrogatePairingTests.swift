import Foundation
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttySurrogatePairingTests {
  private let grinning = "😀" as NSString

  @Test func halvesCommittedApartArriveAsOneCharacter() {
    var pairing = GhosttySurrogatePairing()
    let lead = NSString(characters: [grinning.character(at: 0)], length: 1)
    let trail = NSString(characters: [grinning.character(at: 1)], length: 1)
    #expect(pairing.text(for: lead) == "")
    #expect(pairing.text(for: trail) == "😀")
  }

  @Test func aTrailWithNoLeadIsDropped() {
    var pairing = GhosttySurrogatePairing()
    let trail = NSString(characters: [grinning.character(at: 1)], length: 1)
    #expect(pairing.text(for: trail) == "")
  }

  @Test func ordinaryTextPassesThroughAndForgetsAWaitingLead() {
    var pairing = GhosttySurrogatePairing()
    _ = pairing.text(for: NSString(characters: [grinning.character(at: 0)], length: 1))
    #expect(pairing.text(for: "a") == "a")
    #expect(pairing.text(for: NSString(characters: [grinning.character(at: 1)], length: 1)) == "")
  }
}

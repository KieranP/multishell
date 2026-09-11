import Foundation

/// The sha256 of a file's bytes, the core importing Foundation only. Names
/// inside are FIPS 180-4's, to be checked against the document.
public enum FileDigest {
  /// The digest of `data`, sixty-four hex characters.
  public static func sha256(of data: Data) -> String {
    var state = initialState
    var message = [UInt8](data)
    let bits = UInt64(message.count) * 8
    // The padding: a one bit, zeroes to 56 bytes of the last block, then
    // the length in bits big-endian.
    message.append(0x80)
    while message.count % 64 != 56 { message.append(0) }
    for shift in stride(from: 56, through: 0, by: -8) {
      message.append(UInt8(truncatingIfNeeded: bits >> UInt64(shift)))
    }
    var schedule = [UInt32](repeating: 0, count: 64)
    for block in stride(from: 0, to: message.count, by: 64) {
      for i in 0..<16 {
        let at = block + i * 4
        schedule[i] =
          UInt32(message[at]) << 24 | UInt32(message[at + 1]) << 16
          | UInt32(message[at + 2]) << 8 | UInt32(message[at + 3])
      }
      for i in 16..<64 {
        let fifteen = schedule[i - 15]
        let two = schedule[i - 2]
        let s0 = rotated(fifteen, 7) ^ rotated(fifteen, 18) ^ (fifteen >> 3)
        let s1 = rotated(two, 17) ^ rotated(two, 19) ^ (two >> 10)
        schedule[i] = schedule[i - 16] &+ s0 &+ schedule[i - 7] &+ s1
      }
      var (a, b, c, d) = (state[0], state[1], state[2], state[3])
      var (e, f, g, h) = (state[4], state[5], state[6], state[7])
      for i in 0..<64 {
        let s1 = rotated(e, 6) ^ rotated(e, 11) ^ rotated(e, 25)
        let choice = (e & f) ^ (~e & g)
        let t1 = h &+ s1 &+ choice &+ constants[i] &+ schedule[i]
        let s0 = rotated(a, 2) ^ rotated(a, 13) ^ rotated(a, 22)
        let majority = (a & b) ^ (a & c) ^ (b & c)
        let t2 = s0 &+ majority
        (h, g, f, e) = (g, f, e, d &+ t1)
        (d, c, b, a) = (c, b, a, t1 &+ t2)
      }
      for (i, word) in [a, b, c, d, e, f, g, h].enumerated() {
        state[i] = state[i] &+ word
      }
    }
    return state.map { String(format: "%08x", $0) }.joined()
  }

  private static func rotated(_ value: UInt32, _ places: UInt32) -> UInt32 {
    value >> places | value << (32 - places)
  }

  /// The first 32 bits of the fractional parts of the square roots of the
  /// first eight primes.
  private static let initialState: [UInt32] = [
    0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a,
    0x510e_527f, 0x9b05_688c, 0x1f83_d9ab, 0x5be0_cd19,
  ]

  /// The same of the cube roots of the first sixty-four primes.
  private static let constants: [UInt32] = [
    0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5,
    0x3956_c25b, 0x59f1_11f1, 0x923f_82a4, 0xab1c_5ed5,
    0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3,
    0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7, 0xc19b_f174,
    0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc,
    0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc, 0x76f9_88da,
    0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7,
    0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351, 0x1429_2967,
    0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13,
    0x650a_7354, 0x766a_0abb, 0x81c2_c92e, 0x9272_2c85,
    0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3,
    0xd192_e819, 0xd699_0624, 0xf40e_3585, 0x106a_a070,
    0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5,
    0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f, 0x682e_6ff3,
    0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208,
    0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7, 0xc671_78f2,
  ]
}

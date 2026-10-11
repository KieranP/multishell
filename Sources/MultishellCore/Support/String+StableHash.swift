extension String {
  /// FNV-1a of the UTF-8, the same every launch, which `hashValue` is not.
  var stableHash: UInt32 {
    utf8.reduce(2_166_136_261) { hash, byte in (hash ^ UInt32(byte)) &* 16_777_619 }
  }
}

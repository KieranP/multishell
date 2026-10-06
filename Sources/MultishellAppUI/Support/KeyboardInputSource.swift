import Carbon.HIToolbox

enum KeyboardInputSource {
  static var currentID: String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
      let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    else { return nil }
    return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
  }
}

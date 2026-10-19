/// Where a `style` or `on…` word stands that may name an attribute, read from the text
/// so the tree is asked about those alone; nearly every attribute is neither.
enum InjectableAttributeCandidates {
  /// HTML's and SVG animation's event handler attributes less their `on`, with pointer, touch,
  /// animation, transition, fullscreen, scroll snap, `search`, `mousewheel` and `webkit…` events.
  private static let handledEvents: Set<String> = [
    "abort", "afterprint", "animationcancel", "animationend", "animationiteration",
    "animationstart", "auxclick", "beforeinput", "beforematch", "beforeprint", "beforetoggle",
    "beforeunload", "begin", "blur", "cancel", "canplay", "canplaythrough", "change", "click",
    "close", "command", "contentvisibilityautostatechange", "contextlost", "contextmenu",
    "contextrestored", "copy", "cuechange", "cut", "dblclick", "drag", "dragend", "dragenter",
    "dragleave", "dragover", "dragstart", "drop", "durationchange", "emptied", "end", "ended",
    "error", "focus", "focusin", "focusout", "formdata", "fullscreenchange", "fullscreenerror",
    "gotpointercapture", "hashchange", "input", "invalid", "keydown", "keypress", "keyup",
    "languagechange", "load", "loadeddata", "loadedmetadata", "loadstart", "lostpointercapture",
    "message", "messageerror", "mousedown", "mouseenter", "mouseleave", "mousemove", "mouseout",
    "mouseover", "mouseup", "mousewheel", "offline", "online", "pagehide", "pagereveal", "pageshow",
    "pageswap", "paste", "pause", "play", "playing", "pointercancel", "pointerdown", "pointerenter",
    "pointerleave", "pointermove", "pointerout", "pointerover", "pointerrawupdate", "pointerup",
    "popstate", "progress", "ratechange", "rejectionhandled", "repeat", "reset", "resize", "scroll",
    "scrollend", "scrollsnapchange", "scrollsnapchanging", "search", "securitypolicyviolation",
    "seeked", "seeking", "select", "selectionchange", "selectstart", "slotchange", "stalled",
    "storage", "submit", "suspend", "timeupdate", "toggle", "touchcancel", "touchend", "touchmove",
    "touchstart", "transitioncancel", "transitionend", "transitionrun", "transitionstart",
    "unhandledrejection", "unload", "volumechange", "waiting", "webkitanimationend",
    "webkitanimationiteration", "webkitanimationstart", "webkittransitionend", "wheel",
  ]

  private static let style = Array("style".utf16)
  private static let on = Array("on".utf16)
  private static let nameJoiners = Set("-.:_".utf16)
  private static let lowercaseS = UInt16(UInt8(ascii: "s"))
  private static let lowercaseO = UInt16(UInt8(ascii: "o"))

  /// In text order, bare or not, and in text content too. An array: a one-pass
  /// reader of the string's own view took 47 ms on 1 MiB, this 2.
  static func candidates(in text: [UInt16]) -> [InjectableAttributeCandidate] {
    var found: [InjectableAttributeCandidate] = []
    var index = 0
    while index < text.count {
      let first = text[index] | ASCIIUnits.lowercaseBit
      guard first == lowercaseS || first == lowercaseO,
        index == 0 || !isNameUnit(text[index - 1])
      else {
        index += 1
        continue
      }
      let end = text[index...].firstIndex { !isNameUnit($0) } ?? text.count
      if let kind = kind(of: text[index..<end]) {
        found.append(InjectableAttributeCandidate(range: index..<end, kind: kind))
      }
      index = max(end, index + 1)
    }
    return found
  }

  /// `style`, or `on` and one of the events above, in any case; only a handler's
  /// event becomes a string, to look it up.
  private static func kind(of name: ArraySlice<UInt16>) -> InjectableAttributeCandidate.Kind? {
    let lowered = name.lazy.map { $0 | ASCIIUnits.lowercaseBit }
    if lowered.elementsEqual(style) { return .style }
    guard name.count > on.count, lowered.starts(with: on),
      name.dropFirst(on.count).allSatisfy(ASCIIUnits.isLetter)
    else { return nil }
    let event = String(decoding: lowered.dropFirst(on.count), as: UTF16.self)
    return handledEvents.contains(event) ? .handler : nil
  }

  /// Letters, digits and what HTML and Svelte names join them with.
  private static func isNameUnit(_ unit: UInt16) -> Bool {
    ASCIIUnits.isLetter(unit) || ASCIIUnits.isDigit(unit) || nameJoiners.contains(unit)
  }
}

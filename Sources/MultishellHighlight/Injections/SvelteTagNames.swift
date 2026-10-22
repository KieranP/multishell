/// Which Svelte tags are DOM elements, whose `style` and `on…` attributes are CSS and
/// JavaScript; anything else takes them as string props. Read from units, 40,000 tags a file.
enum SvelteTagNames {
  /// Svelte 4 drops a string attribute on `svelte:window`, `document` or `body`, and 5 rejects it.
  private static let elementTag = Array("svelte:element".utf16)
  private static let sveltePrefix = Array("svelte:".utf16)
  /// Svelte parses `<slot>` as a SlotElement, whose attributes are props it passes on.
  private static let slot = Array("slot".utf16)

  static func isElement(_ name: ArraySlice<UInt16>) -> Bool {
    if name.starts(with: sveltePrefix) { return name.elementsEqual(elementTag) }
    return !isComponent(name) && !name.elementsEqual(slot)
  }

  /// As Svelte's parser reads one: a name starting with an uppercase letter, or dotted.
  /// The grammar parses only a tag starting with an ASCII letter.
  private static func isComponent(_ name: ArraySlice<UInt16>) -> Bool {
    guard let first = name.first else { return false }
    return ASCIIUnits.isUppercaseLetter(first) || name.contains(ASCIIUnits.dot)
  }
}

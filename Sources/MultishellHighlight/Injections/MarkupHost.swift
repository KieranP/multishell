/// A language whose files hold scripts and styles, and how it reads them. A new one
/// is a case each reader's `switch` must answer for, not a check it may miss.
enum MarkupHost {
  case html
  case svelte

  /// A browser matches `LANG` as `lang`, allows `lang = "ts"` and decodes `text&#47;javascript`;
  /// Svelte's preprocessors find `lang=` and `type=` by regex, exactly as written.
  var readsAttributesAsABrowserDoes: Bool {
    switch self {
    case .html: true
    case .svelte: false
    }
  }

  /// Whether a tag's `style` and `on…` are CSS and JavaScript: a Svelte component
  /// takes either as a string prop.
  func injectsAttributes(ofTag name: ArraySlice<UInt16>) -> Bool {
    switch self {
    case .html: true
    case .svelte: SvelteTagNames.isElement(name)
    }
  }
}

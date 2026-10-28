import MultishellAppCore

/// A language whose files hold others: markup in its elements and attributes,
/// Markdown in its fenced code blocks.
enum InjectionHost {
  case markdown
  case markup(MarkupHost)

  /// Exhaustive, so a new language must say whether it hosts others.
  init?(_ language: HighlightLanguage) {
    switch language {
    case .html: self = .markup(.html)
    case .markdown: self = .markdown
    case .svelte: self = .markup(.svelte)

    case .bash, .c, .cpp, .cSharp, .css, .golang, .java, .javaScript, .json, .kotlin, .makefile,
      .php, .python, .ruby, .rust, .scss, .sql, .swift, .toml, .tsx, .typeScript, .yaml, .zig:
      return nil
    }
  }
}

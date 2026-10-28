/// A language a file tab highlights, each a grammar built into the app.
/// The list grows on request, each grammar costing build time and binary size.
public enum HighlightLanguage: Hashable, Sendable, CaseIterable {
  case bash
  case c
  case cpp
  case cSharp
  case css
  case golang
  case html
  case java
  case javaScript
  case json
  case kotlin
  case makefile
  case markdown
  case php
  case python
  case ruby
  case rust
  case scss
  case sql
  case svelte
  case swift
  case toml
  case tsx
  case typeScript
  case yaml
  case zig

  private static let byExtension: [String: Self] = [
    "bash": .bash, "c": .c, "cjs": .javaScript, "go": .golang, "h": .c, "js": .javaScript,
    "json": .json, "jsx": .javaScript, "markdown": .markdown, "md": .markdown, "mjs": .javaScript,
    "gemspec": .ruby, "py": .python, "pyi": .python, "rake": .ruby, "rb": .ruby, "rs": .rust,
    "ru": .ruby, "sh": .bash, "swift": .swift, "toml": .toml,
    "ts": .typeScript, "mts": .typeScript, "cts": .typeScript, "tsx": .tsx, "yaml": .yaml,
    "yml": .yaml, "zig": .zig, "zon": .zig, "zsh": .bash,
    "c++": .cpp, "cc": .cpp, "cpp": .cpp, "cxx": .cpp, "h++": .cpp, "hh": .cpp, "hpp": .cpp,
    "hxx": .cpp, "cs": .cSharp, "java": .java, "kt": .kotlin, "kts": .kotlin, "mak": .makefile,
    "mk": .makefile, "php": .php, "phtml": .php, "sql": .sql, "css": .css, "htm": .html,
    "html": .html, "scss": .scss, "svelte": .svelte,
  ]

  /// Files whose language their name says rather than an extension.
  private static let byFileName: [String: Self] = [
    ".bash_profile": .bash, ".bashrc": .bash, ".prettierrc": .json, ".profile": .bash,
    ".swift-format": .json, ".zprofile": .bash, ".zshrc": .bash, "Brewfile": .ruby,
    "Cargo.lock": .toml, "Fastfile": .ruby, "GNUmakefile": .makefile, "Gemfile": .ruby,
    "Guardfile": .ruby, "Makefile": .makefile, "Package.resolved": .json, "Pipfile": .toml,
    "Podfile": .ruby, "Rakefile": .ruby, "Vagrantfile": .ruby, "makefile": .makefile,
  ]

  private static let byInterpreter: [String: Self] = [
    "bash": .bash, "node": .javaScript, "php": .php, "python": .python, "python3": .python,
    "ruby": .ruby, "sh": .bash, "swift": .swift, "zsh": .bash,
  ]

  /// Names a Markdown fence may give where no extension or interpreter says the same.
  private static let byCodeFenceName: [String: Self] = [
    "c#": .cSharp, "csharp": .cSharp, "golang": .golang, "javascript": .javaScript,
    "jsonc": .json, "kotlin": .kotlin, "make": .makefile, "makefile": .makefile,
    "rust": .rust, "shell": .bash, "typescript": .typeScript,
  ]

  /// A fenced code block's language from the first word of its info string, by name,
  /// extension or interpreter in any case, as GitHub reads it.
  public static func language(forCodeFence name: String) -> Self? {
    let folded = name.lowercased()
    return byCodeFenceName[folded] ?? byExtension[folded] ?? byInterpreter[folded]
  }

  /// By extension, then by the file's name, then by a shebang; anything else
  /// is plain text.
  public static func language(forPath path: String, firstLine: String?) -> Self? {
    let name = path.split(separator: "/").last.map(String.init) ?? path
    if let dot = name.lastIndex(of: "."), dot != name.startIndex,
      let found = byExtension[name[name.index(after: dot)...].lowercased()]
    {
      return found
    }
    if let found = byFileName[name] { return found }
    guard let firstLine, firstLine.hasPrefix("#!") else { return nil }
    let words = firstLine.dropFirst(2).split(separator: " ")
    // `#!/usr/bin/env python3` names the interpreter after `env`.
    let program = words.first.map { $0.split(separator: "/").last.map(String.init) ?? "" }
    let interpreter = program == "env" ? words.dropFirst().first.map(String.init) : program
    return interpreter.flatMap { byInterpreter[$0] }
  }
}

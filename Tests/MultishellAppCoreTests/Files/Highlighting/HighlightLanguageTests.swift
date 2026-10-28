import Testing

@testable import MultishellAppCore

@Suite
struct HighlightLanguageTests {
  @Test func aLanguageIsPickedByExtensionThenNameThenShebang() {
    #expect(
      HighlightLanguage.language(forPath: "Sources/App/main.swift", firstLine: nil) == .swift
    )
    #expect(HighlightLanguage.language(forPath: "Package.swift", firstLine: nil) == .swift)
    #expect(
      HighlightLanguage.language(forPath: "scripts/run", firstLine: "#!/usr/bin/env swift")
        == .swift
    )
    #expect(HighlightLanguage.language(forPath: "Rakefile", firstLine: nil) == .ruby)
    for json in [".prettierrc", "web/.prettierrc", ".swift-format", "Package.resolved"] {
      #expect(HighlightLanguage.language(forPath: json, firstLine: nil) == .json, "\(json)")
    }
    #expect(HighlightLanguage.language(forPath: "lib/Gemfile", firstLine: nil) == .ruby)
    #expect(
      HighlightLanguage.language(forPath: "bin/x", firstLine: "#!/usr/bin/env ruby") == .ruby
    )
    #expect(HighlightLanguage.language(forPath: "README", firstLine: "hello") == nil)
    #expect(
      HighlightLanguage.language(forPath: ".swift", firstLine: nil) == nil,
      "a dot file, not an extension",
    )
  }

  @Test(arguments: [
    ("App.cs", HighlightLanguage.cSharp), ("main.cpp", .cpp), ("vec.hpp", .cpp), ("x.cc", .cpp),
    ("index.php", .php), ("Main.java", .java), ("App.kt", .kotlin), ("build.gradle.kts", .kotlin),
    ("Makefile", .makefile), ("GNUmakefile", .makefile), ("rules.mk", .makefile),
    ("schema.sql", .sql), ("lib.h", .c), ("App.svelte", .svelte), ("index.html", .html),
    ("page.htm", .html), ("site.css", .css), ("_theme.scss", .scss),
  ])
  func eachAddedLanguageIsPickedByItsExtensionOrName(path: String, language: HighlightLanguage) {
    #expect(HighlightLanguage.language(forPath: path, firstLine: nil) == language)
  }

  @Test func aPHPScriptIsPickedByItsShebang() {
    #expect(
      HighlightLanguage.language(forPath: "bin/run", firstLine: "#!/usr/bin/env php") == .php
    )
  }

  @Test(arguments: [
    ("swift", HighlightLanguage.swift), ("JavaScript", .javaScript), ("JS", .javaScript),
    ("shell", .bash), ("zsh", .bash), ("C#", .cSharp), ("jsonc", .json), ("Makefile", .makefile),
    ("python3", .python), ("node", .javaScript),
  ])
  func aCodeFenceIsPickedByNameExtensionOrInterpreterInAnyCase(
    name: String,
    language: HighlightLanguage,
  ) {
    #expect(HighlightLanguage.language(forCodeFence: name) == language)
  }

  @Test func aCodeFenceNamingNoGrammarHereIsPlain() {
    #expect(HighlightLanguage.language(forCodeFence: "text") == nil)
    #expect(HighlightLanguage.language(forCodeFence: "") == nil)
  }
}

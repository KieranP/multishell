# Strings and languages

What a user-visible string, a translation or a highlighted language needs beyond
the code itself.

- **A user-visible string.** A line in the catalogue of the half that says it,
  in key order under its thing's prefix (design/translation.md), and the lookup
  where the words are wanted.
- **A form whose wording turns on a number** goes in the counted-forms file
  instead and takes the number like any other argument. Two or more arguments
  are numbered so a translation may reorder them.
- **A service a pane can reach.** A usage string in the Info.plist template, in
  this app's words, and the matching entitlement where the hardened runtime has
  one. Neither stands in for the other (design/signing.md, permissions.md).
- **A language.** That code's folder beside the English one in both halves, both
  files translated, and a line for it in each target's resources in the
  manifest.
- **The permission strings are not in the catalogue**: English stays in the
  Info.plist template, and a translation is an `InfoPlist.strings` in that
  language's folder in the app half, which the script copies into the bundle's
  resources on its own.
- **A highlighted language.** A case in `HighlightLanguage` with its extensions,
  file names and interpreters, and a row in
  `eachAddedLanguageIsPickedByItsExtensionOrName`; the grammar's row in
  `Scripts/fetch-grammars.sh`, at a tag committing its parser or a revision
  where no tag does, with its archive's SHA-256, and in `Package.swift` its
  `.package(path:)` and its product in MultishellHighlight's dependencies
  (dependencies.md); where the package drops its scanner, the scanner and what
  it includes copied under `ThirdParty/tree-sitter/`, with a README naming the
  tag and commit, and listed in `TreeSitterScanners`' `sources`; its entry in
  `HighlightGrammars.sources`; any capture name whose first component misleads
  in `HighlightCaptureRoles`, under `exceptionsByLanguage` where only this
  grammar means it so; a case in `eachGrammarColoursAWordOfItsLanguage`; and its
  notice and licence text. One that holds other languages also needs a case in
  `InjectionHost`, whose `switch`es in `HighlightInjections.query` and `find`
  ask for its injection query and how its captures become injections; a markup
  language also needs one in `MarkupHost`, whose every `switch` asks how it
  reads its attributes and its script and style languages. A name a Markdown
  fence gives that no extension or interpreter says goes in
  `HighlightLanguage.byCodeFenceName`.

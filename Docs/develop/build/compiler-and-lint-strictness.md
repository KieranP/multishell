# How strict the compiler and the lints are

- **Every target imports each module it uses** (`MemberImportVisibility`).
  Without it a file could use another module's extension members while any file
  in its target imported that module, so a clean build proved no import dead:
  three imports removed on that evidence were needed, and 56 files used a module
  they never imported.
- **`any` is written on every existential** (`ExistentialAny`), and **a warning
  fails the build**, bar the one the copied tree-sitter scanners turn off and
  the grammar packages' own, which are printed but reach none of our targets
  (dependencies.md).
- **StrictMemorySafety is off**: 427 sites, nearly all libghostty's C API and
  Darwin's, each wanting an `unsafe` that says nothing a reader can act on.
  `InternalImportsByDefault` and `ImmutableWeakCaptures` found nothing here, so
  they are left for Swift 7 to turn on.
- **swift-format rules still off**, listed here because `.swift-format` is JSON
  and takes no comments: `NoLeadingUnderscores` (a persisted `_0` coding key),
  `UseWhereClausesInForLoops` (a `guard … continue` reads as the rest do),
  `NeverForceUnwrap` and `NeverUseForceTry` (SwiftLint's own rules cover
  Sources), `AllPublicDeclarationsHaveDocumentation` (733 undocumented), and
  `BeginDocumentationCommentWithOneLineSummary`, 965 doc comments written as
  prose.
- **Every SwiftLint rule runs but those in `disabled_rules`**, each with its
  reason in `.swiftlint.yml`. Layout rules run beside swift-format where the two
  agree; where they disagree, as on brace placement after a full header, import
  order and a lone wrapped element's trailing comma, swift-format's answer
  stands. They cost about 0.3 s of SwiftLint's 1.1 s uncached; swift-format
  takes 7 s serial and 1.5 to 4 s with `--parallel`, which `make` passes.
- **SwiftLint is pinned by `swiftlint_version`**, and any other version refuses
  to run. With every rule on, a newer SwiftLint would switch its new rules on
  unasked, so a bump is when they are reviewed. CI downloads that release;
  locally, Homebrew's must match.
- **Sources take no force unwrap, `try!` or `as!`**; the one left is marked
  where it stands. `Tests/.swiftlint.yml` lets a test stop on a broken fixture,
  lets a suite run as long as its cases, and keeps `#expect(x == [])` over
  `isEmpty`, since it prints `x` when it fails.
- **Size and complexity limits sit just above the largest that exists**: 60-line
  functions, complexity 15, 9 parameters, 4-member tuples, types nested two
  deep, 120-column lines. They stop growth rather than force a split. Three
  exceed them by choice and are marked: `SVGPathParser.path(fromData:)` (kept
  whole on 2026-09-30), `Workspace.init(from:)`, a field per line, and
  `AppModel.reply(to:)`, one case per control request; `WorkspaceStore` passes
  400 lines because every writer of its `private(set)` state must live in the
  file, and `AppModel` because no extension may hold a stored property.
- **Members sit in SwiftLint's `type_contents_order`**: cases, type aliases,
  nested types, static then instance properties, initializers, static then
  instance methods, subscripts, `deinit`. Defaulted parameters come last.
- **Enum cases are alphabetical unless the order means something**: what a
  picker, the board, a strip or the helper's usage error lists in that order,
  the order file lists are placed or a create or remove's stages run, the badge
  fit's widest-first. Each such enum is marked with its reason. SwiftLint checks
  top-level enums only; a nested one follows the rule unchecked and unmarked.
- **A type's extension in its own file is folded into it**, except where it
  keeps a memberwise init synthesized, and `WorkspaceStore`'s concerns, which
  must share its file. Those are marked.
- **SwiftLint's analyzer is not run.** Tried on 2026-10-09: over 30 minutes for
  one pass, `unused_declaration` found 4 and all 4 were wrong (a `@State` read
  through `$`, a protocol witness, a kept-alive `let`), and `unused_import`
  mostly asked for `Darwin` where `Foundation` already brings it. It needs
  SwiftPM's `@file` source lists expanded by hand, too. `MemberImportVisibility`
  already fails the build on a missing import.

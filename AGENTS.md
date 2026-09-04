# For agents working in this repository

Read these before changing anything:

- `DEVELOP.md`: how to build and test, where things live, the rules CI
  enforces, how to add an engine, theme or platform.
- `DESIGN.md`: the decisions behind the architecture and behaviour, with the
  reasons and costs. Do not undo one without knowing what it cost to make; a
  few record features that were removed on purpose.

Working rules:

- The three root libraries import Foundation only. `Paths.swift` is the only
  core file allowed `#if os(...)`. Platform code goes behind `Ports/`.
- Views call `AppModel`; they never touch the store, a host, or git.
- Run `make format` on anything you touched, then `make lint`, `make test`
  (both packages) and `make build`. All must pass before you say something
  works.
- Every persisted field decodes with a default. Add a case to
  `DecodingDefaultsTests` when you add one.
- Test git behaviour against a real repository with `RepositoryFixture`, not
  with mocks. Test parsers on fixture text.
- Small single-purpose files. Comments only for why, non-local consequences,
  or facts the code cannot show. No restatements.
- Nothing is committed unless the user asks.

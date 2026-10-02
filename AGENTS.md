# Multishell, for agents

An index. Pull in the file you need; do not read them all. Rules live with their
reasons, so a file under `Docs/design/` is binding and not background.

Five rules live here, then the code design rules. The rest are in the files
below.

- Before changing code in an area, read the `Docs/design/` file that covers it;
  the table in [Docs/DESIGN.md](Docs/DESIGN.md) says which.
- Commit only when the user explicitly asks.
- No code comment exceeds two lines. Where more is needed, add it to a file
  under `Docs/design/` or `Docs/develop/` and refer to it from the comment.
- When fixing a bug, write a failing test first where practical, then fix it.
- `public` only where another target reads it. A function, type or property one
  library uses stays internal, and the tests reach it with `@testable`; an
  internal type's members carry no `public` either. See
  [Docs/develop/layout.md](Docs/develop/layout.md).

## Core Code Design Rules

- One top-level type per file, named for it. An extension of another type goes
  in `<Type>+<Concern>.swift`; a nested type stays with its parent.
- A helper that would be `private` gets an internal file of its own beside the
  type it serves.
- A file's folder follows what it is, never how many places call it.
- A file holds one concern. Split it when it holds two; no `MARK` banners.
- Names say what a thing is or does, in full words. A name never promises more
  or less than the code does.
- One word per concept across a file and its siblings, and no word for two
  concepts: "collapsed" for a chevron, since "folded" already means case
  folding.
- A closure reporting an event is `on<Event>`, `onWillTerminate`; one a view
  calls to act is named for the act, `select` or `drop`. A Bool reads as a
  claim: `isRetryable`, `showsBands`.
- A decision a view makes is a plain value or an `AppModel` method in
  MultishellAppCore, tested there. The view only reads it or forwards the
  answer.
- A measurement two views share lives in `UIMetrics`, never as a formula copied
  between them.
- A setter the app never calls is `internal(set)`.
- A rename never changes a persisted key; `CodingKeys` keeps the old one.
- No dead code and no copies of a helper; reuse the one there is.
- Comments only say why. Delete one that restates the code or names the wrong
  line.
- A test suite mirrors the path of the file it tests, with its harnesses at the
  suite root. A test's name is a sentence about behaviour, and its assertions
  must reach the path that name claims.

## Where the rest is

- [Docs/DEVELOP.md](Docs/DEVELOP.md) indexes `Docs/develop/`: the build, the
  tests, the layout, what an addition needs, what is on disk, what macOS asks
  for, the dependencies, the open findings and the queued work.
- [Docs/DESIGN.md](Docs/DESIGN.md) indexes `Docs/design/`: why each decision
  went the way it did, and the rules that follow from it.

# Multishell, for agents

An index. Pull in the file you need; do not read them all. Rules live with their
reasons, so a file under `Docs/design/` is binding and not background.

Four rules live here. The rest are in the files below.

- Commit only when the user explicitly asks.
- No code comment exceeds two lines. Where more is needed, add it to a file
  under `Docs/design/` or `Docs/develop/` and refer to it from the comment.
- When fixing a bug, write a failing test first where practical, then fix it.
- `public` only where another target reads it. A function, type or property one
  library uses stays internal, and the tests reach it with `@testable`; an
  internal type's members carry no `public` either. See
  [Docs/develop/layout.md](Docs/develop/layout.md).

## Where the rest is

- [Docs/DEVELOP.md](Docs/DEVELOP.md) indexes `Docs/develop/`: the build, the
  tests, the layout, what is on disk, what macOS asks for, the dependencies and
  the open findings.
- [Docs/DESIGN.md](Docs/DESIGN.md) indexes `Docs/design/`: why each decision
  went the way it did, and the rules that follow from it.

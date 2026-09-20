# Contributing

Issues are open to anyone. Pull requests are not: GitHub is set to take them
from this repository's collaborators only, so opening one is not something the
site will let you do rather than something that gets turned down. Nothing
personal, and nothing about your change. Every line here was written by an AI
under one person's direction, against design notes that are binding, and
reviewing outside work against those costs more than writing it.

## What to send instead

Open an issue. A bug report that names the version, the shell and the steps is
worth more than a patch, and the same goes for a feature: say what you are
trying to do and what gets in the way. [SECURITY.md](SECURITY.md) covers a
vulnerability, which goes privately rather than into an issue.

If you want the change in your own hands, the licence is the GNU AGPL v3: fork
it, and keep the source of what you distribute open under the same terms.

## For collaborators

Read [AGENTS.md](AGENTS.md). It indexes `Docs/develop/` for the build, the tests
and the rules, and `Docs/design/` for why things are the way they are. A file
under `Docs/design/` is binding, not background: if a change contradicts one,
the change says why and the file is updated with it.

```sh
make format   # rewrite to project style
make lint     # what CI runs, --strict: a warning fails
make test     # libraries and model, then the Mac hosts
make build    # bundle it, which CI does not do for you
```

All four have to pass. [Docs/develop/build.md](Docs/develop/build.md) covers
what you cannot verify from a terminal: there is no screen and no Apple events,
so say what you checked rather than that it works.

Fixing a bug starts with a test that fails on the bug and passes on the fix.
[Docs/develop/tests.md](Docs/develop/tests.md) has the conventions a new one
follows, and [Docs/develop/adding.md](Docs/develop/adding.md) lists what an
addition needs beyond its code, per kind of addition. User-visible strings go
through the catalogues, never into a view; see
[Docs/design/translation.md](Docs/design/translation.md).

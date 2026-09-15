# Reduce comments

Default to none. Prefer renaming the variable, extracting a named function, or
naming the constant. A comment is the fallback when naming cannot carry it.

**Comment only for**: why this and not the obvious alternative; non-local
consequences ("callers rely on this staying sorted"); facts unreadable from the
code, such as an API quirk, a spec clause, a measured number, or a
version-specific workaround; a deliberate oddity a reader would flag as a
mistake; public API docs where the project already has them.

**Never**: restatements (`// increment i`); section banners; docstrings that
re-spell the signature; ownerless TODOs; commented-out code, delete it; a
comment repeating the name below it.

**Style**: one or two lines, above the code, present tense.

    Bad:  // Retry 3 times
    Good: // Concurrent batches trip the API's secondary rate limit.

**Not between the entries of a hash, array, or type body.** A comment inside
the literal breaks the scan down the keys, and the next edit to the list
orphans it. Hoist the value into a named constant or variable and comment it
there.

    Bad:  options = {
            # The API rejects a page limit over 200
            page_limit: 200,
            retries: 3,
          }

    Good: # The API rejects a page limit over 200
          PAGE_LIMIT = 200

          options = { page_limit: PAGE_LIMIT, retries: 3 }

A field of an `interface` or `type` has no value to hoist, so name its type
instead and comment that:

    Bad:  interface Task {
            // ISO 8601, the API rejects other formats
            dueAt: string
            title: string
          }

    Good: // ISO 8601, the API rejects other formats
          type IsoDate = string

          interface Task {
            dueAt: IsoDate
            title: string
          }

A comment above the whole literal or interface is fine.

**In tests, none.** The suite and case names already say the setup and the
expectation, so a comment is a third restatement. Rewrite the name instead. The
exception is what the test cannot state itself: why a stub returns this odd
shape, which upstream bug the fixture reproduces.

When editing, delete stale or restating comments, but do not strip a
codebase's conventions or public API docs wholesale, and do not add comments to
code you merely touched. Project rules in AGENTS.md or CLAUDE.md win.

## "Simplify the comments" means the ones in the diff

Default scope is what this branch added or changed, per `git diff <base>..HEAD`
with the base derived as `git-diff.md` says. A comment already in the file is
someone else's decision, and rewriting a whole file's worth has had to be
reverted here. Widen only when told to, in words like "the whole file"; if the
ask is ambiguous, do the diff-scoped pass and name what you left alone.

Before a cutting pass, say what goes: how many comments, in how many files.
Report the result in numbers, "31 comments to 9 across 7 files", never
"simplified the comments".

---
name: better-commit-messages
description: "How to write a git commit message: subject, body, and co-author trailer."
user-invocable: false
---

# Commit messages

`git status --porcelain` first; it is the authority on what is staged,
unstaged, and untracked. Then read the diff that will actually be committed:

- Anything staged: that is the commit. Write from `git diff --cached`.
- Nothing staged: all of it is going in. Write from `git diff`.

Write from the diff, not from the conversation.

Two cases to flag in one line above the message, rather than fold in or fix:
a file that is both staged and further modified, so the commit is a partial
snapshot of it, and untracked files that look like they belong in this change.

## Shape, and never more

    <tag> <subject>

    <paragraph 1: the primary change>

    <paragraph 2: only if a reviewer would be surprised>

    <Co-Authored-By: line>

No third paragraph, bullets, headings, labels, or emoji.

**Tag.** A fix leads with the repo's issue-tracker reference, `[TICKET-1234]`,
or the error-tracker item, `[Errors#20893]`, or both when a ticket tracks an
error item, the issue tracker first: `[TICKET-3414] [Errors#20893]`. Read the
log for the forms this repo uses. Take the number from an explicit argument,
else the branch name, else the session. With none of those omit it, never
invent one, and ask when the change looks ticket-related but the number is
unclear. A tooling change with no ticket takes a scope prefix already in the
log, such as `Lint:` or `Claude:`.

**Subject.** Imperative, sentence case, no trailing period, 72 chars or fewer
including the tag. Name the behaviour, not the files. No `feat:` prefix. Never
append a PR number like `(#7714)`; GitHub adds that on squash-merge.
Good: `[TICKET-1234] Reject uploads above the configured size limit`.
Bad: `Fixed a bug in the date parsing logic`.

**Body.** Wrap at 72. Why, never a file-by-file recap. For a fix, the root
cause naming the failing call. For a feature, the constraint forcing this
shape. Paragraph 2 only for an incidental change, deleted dead code, or a
commit reverted by short SHA. Skip the body when the subject says it all: dep
bump, rename, lint rule. Never mention Claude or the session.

**Trailer.** Blank line, then the exact `Co-Authored-By:` line from your system
prompt. Never copy one from an older commit or from the example below.

## Example

    [TICKET-20902] Report the missing option list with a backtrace

    The error reporter only builds a trace when it is handed an exception
    object, so the bare string reported here produced a payload with no
    frames. Wrap the report in a dedicated error class with an explicit
    caller backtrace.

    <Co-Authored-By: line>

Output the finished message and nothing else of substance. Whether it is then
used to commit is decided by the caller, not here.

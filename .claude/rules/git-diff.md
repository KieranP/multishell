# Reading a git diff

**`git diff` never shows untracked files.** A file that was never `git add`ed is
invisible to every diff command, and a new file is often the whole point of the
branch. Take the `??` entries from `git status --porcelain` and read each one as
an added file.

**Read every diff in full.** Do not skim or skip files. Past roughly 50 files or
3000 lines, read it in directory groups rather than one command, so nothing
truncates mid-file.

**Drop the noise, then say what you dropped.** A lockfile carries a hash per
dependency per platform, so one version bump rewrites dozens of lines and
informs nothing. The same goes for generated or minified output and vendored
trees. Exclude them with pathspecs rather than hand-listing the files you do
want, and name what you excluded in one line: a silent omission reads as full
coverage. When a lockfile is the only change, say so; that is a dependency
upgrade, not an empty diff.

    git diff <base>..HEAD --find-renames -- . ':(exclude)vendor/*' \
      ':(exclude)*.lock' ':(exclude)*-lock.*' ':(exclude)*.lock.*'

**Derive `<base>`** with `git merge-base HEAD origin/HEAD`, falling back to
`origin/main` or `origin/master`, then that branch locally. When
`git log <base>..HEAD --oneline` lists commits that have nothing to do with the
branch, the base is wrong: re-derive against the real fork point and name the
base you used. On the default branch diff the working tree instead; on a
detached HEAD, ask. Binary files need no flag, and `--no-binary` does not exist.

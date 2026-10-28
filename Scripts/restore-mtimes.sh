#!/bin/bash
# Dates each tracked file by the last commit that touched it, deepening a shallow
# clone first, so a .build CI restores recompiles only what changed since; build.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Not the submodules' history, which is not needed and Ghostty's is 100 MB.
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  git fetch --quiet --unshallow --no-recurse-submodules
fi

# First parents only, where a merge lists what it changed against main: by its
# branch's commits, a file both sides changed took main's date and went unrebuilt.
git -c core.quotePath=false log --first-parent --format='%x00%ct' --name-only \
  --no-renames HEAD |
  perl -ne '
    # Tracked paths only: on a case-insensitive disk, docs/ in history for
    # Docs/ is the same file and would take the old date.
    BEGIN {
      %tracked = map { chomp; ($_, 1) } `git -c core.quotePath=false ls-files`;
      die "git ls-files failed\n" if $?;
    }
    chomp;
    if (/^\0(\d+)$/) { $time = $1; next }
    next unless $tracked{$_} && !$dated{$_}++;
    utime $time, $time, $_ if -f $_ && !-l $_;
  '

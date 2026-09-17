# Never git stash

`refs/stash` lives in the common git directory, so every worktree of a repo
shares one stack. A stashes, B stashes, A pops and gets B's work. Verified.

Do not run `git stash`, `stash push`, `stash pop`, `stash apply`, `stash drop`,
or `stash clear`. A `Bash(git stash*)` deny rule enforces this; do not look for
a way around it.

## What a deny rule does not catch

`--autostash` on `git rebase` or `git pull`, and the `rebase.autoStash` /
`merge.autoStash` config. Those run as `git pull` or `git rebase`, so the rule
never sees them, and they write the same shared stack. A rebase that stops
partway leaves the entry exposed. Avoid all four.

## Park work instead

Make a throwaway commit and undo it. It captures staged, unstaged, and new files
in one step.

    git add -A
    git commit -qm wip
    # later
    git reset --soft HEAD~1

Everything comes back staged, so restage deliberately if the split mattered.

Or do the other task in its own worktree rather than switching in place.

# Settings

Layering of user, project and repository settings, and the trust that guards a
shipped hook. Newest at the bottom.

## Settings resolve project over global, repo may ship its own

`nil` follows the global. Empty string overrides to "none", for worktree path,
branch prefix, default branch and agent flags only, which have no other spelling
for it, in user settings and a repo's file alike -> an export can carry a
project pinned that way. Agent flags are the one of the four a repo's file
cannot carry: see agents.md. Elsewhere blank = absent, "none" and "no opinion"
coming to the same thing: a field with its own sentinel (agent `none`, shell
`login`) would have two ways to say one thing and lose the distinction next
load, an empty hook is not a hook to trust, an empty file list links nothing.
Cost: a stray empty key on those four fields is an opinion, not a typo.

Repo `.multishell.json` fills only gaps the user left: a team default must never
override a made choice. What it may say (what a worktree opens, whether that
runs the agent, row order) changes only what is drawn -> needs no trust, unlike
a hook.

Three of its fields are not drawn, they name paths on the reader's disk:
`worktreeDirectory` says where git checks a worktree out, `linkedPaths` and
`copiedPaths` say what is carried into it. "Runs nothing, so needs no trust" was
wrong for all three -> a repo could commit `worktreeDirectory: ~/.claude/skills`
and a `SKILL.md`, and creating any worktree installed a global agent skill; or
link `~/.ssh/id_ed25519` into a tree an agent then reads. So a repo's copy of
the three is held to the checkout: `SharedProjectSettings.confined(to:)`, run
once when the file is read and held on the project as
`project.sharedSettings.confined`, since the sidebar asks per row per render. A
tick's reader runs it off the main actor with the parse, since it asks the disk;
export, being one click, confines on the main actor. `.asWritten` beside it is
the file's own words, which only export wants. The directory resolves symlinks,
so a committed link cannot carry it out. The two lists are resolved lexically
against the root and required to land strictly under it, the file not being
there yet; `..` is resolved, never counted, so no spelling of it has to be
anticipated, and the three guards before it stop what would otherwise resolve
inside (`appendingPathComponent` takes `/etc/passwd` as a relative component,
`~` is not expanded, and nothing runs a shell, so a leading `$HOME` is a
directory name; the guard is on a leading `$` alone, a `$` further in being an
ordinary character in a filename). `WorktreeFiles.place` applies the same rule
and then resolves against the disk, which is what catches a symlink, at the end
of the path as well as on the way. A refused value is dropped whole and the
user's own stands -> pointing outside is the user's to do in settings, not the
repository's. The rule reaches only what the file ships: `place` takes
`heldToRepository`, false for a list the user typed, whose source end is then
used as written, `~/.aws.json` resolving to nothing under the checkout and being
skipped as it was before. The destination end is held for everyone, since it
mirrors the entry rather than being asked for; a user's entry landing outside
the worktree is skipped quietly rather than failing the stage. A list is wholly
one or the other, `layered` taking the repo's only where the user's is blank,
and `layered` is where that is lost -> a create decides it once against the
user's own settings and carries it on the value, as `WorktreeFileList`, rather
than passing a flag beside the list at each layer. Costs: a repo can no longer
ship the sibling default `../{project}-worktrees`, only something like
`.worktrees`; the drop is silent, the settings form showing the value in force
rather than the one refused.

That verdict is reached against the bytes that were read, and a branch can
commit the symlink without changing them -> the mtime does not move, nothing
re-reads, and the cached yes stands. So a create asks the disk again,
`reconfineSharedSettings` before `git worktree add`, and stores what it finds.
The two lists get their second look in `WorktreeFiles.place`, which is why only
the directory needs this one. A refusal there is the same silent drop as at read
time rather than a failed create: the checkout lands where the user's own
setting says, and the sheet may have named the other path a moment earlier.

Confinement is not enough on its own: `copiedPaths: .aws.json` names something
inside the checkout, and a gitignored `.aws.json` sitting there is not the
repo's to ask for. The same goes for where a checkout lands. So all three wait
for the one-time yes the hooks wait for, one answer covering the file.
`asksForTrust` and `trustedContentText` are what the question is built from, and
both are asked of the confined value -> the dialog never shows a line trusting
it could not turn on, and a file whose every path is refused asks nothing. The
stored answer's key on disk is still `sharedHooks`: renaming it would drop every
answer already given.

Its hooks run code someone else committed -> one-time yes, held against the
sha256 of the file's bytes, asked when the user selects one of that project's
worktrees. Re-read when mtime moves. Answer kept per file, sixteen of them: the
file is tracked so it differs per branch, and one shared answer would be asked
again on every switch. Asked of the model as `model.effectiveSettings(for:)` and
`model.worktreeSettings(for:)`; the override forms are the exception, through
`model.settings(of:)`, where blank has to keep meaning "follow the global".
Costs: layering must be asked of the model, never `project.settings`; a trust
question can arrive without a click; editing any other key re-asks; a yes
outlives the file.

The gate is one line: `layered` drops what the yes covers
(`withoutWhatTrustCovers`, the same seven fields `trustedContentText` names) and
then puts the rest over the user's, rather than each field asking. The forms
read that view too, through `inherited` -> a caption saying "from
.multishell.json" cannot name a value the layering left out. It said exactly
that about an untrusted `worktreeDirectory` while resolving the global's path
beside it.

Export writes the settings in force back over the repository's file, and what
the user has not trusted is not in force -> exporting would have dropped a
teammate's committed hook silently. So export keeps the file's own words where
the user wrote none, and records trust only where every hook written is the
user's own; otherwise the answer given about the file it rewrites travels to the
new digest, and where none was given none is recorded, the question standing.
Carrying it matters because `mine` is built from the settings in force, where a
refused directory is already gone: comparing the two alone made trusting a file
and then exporting it revoke the yes, and record a no nothing would ask again.
`keeping(from:)` covers all seven fields trust gates, not the four hooks: gating
the directory and the two lists on trust turned them blank for an untrusted
file, and an export then wrote the file without those keys at all.

Grey in a hook editor = inherited, nothing else. Odd shapes, each from a bug: no
prefix on an existing branch; blank worktree directory = the default; `.`, `..`
and an empty slug -> `_`; whitespace-only hook = "none".

Export writes back what it could not read as it was: a key this build has no
field for, a `$schema` line, an order a newer build named, a value of the wrong
type. A teammate committed it and this build has no opinion -> the fields are
put over the file's own keys, never the file rebuilt from the fields. Cost: a
wrong-typed value stays in the file until someone who can read it changes it,
and a blank hook the file held is written back blank.

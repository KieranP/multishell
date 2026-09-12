# Settings

Layering of user, project and repository settings, and the trust that
guards a shipped hook.
Newest at the bottom.

## Settings resolve project over global, repo may ship its own

`nil` follows the global. Empty string overrides to "none", for worktree path,
branch prefix, default branch and agent flags only, which have no other spelling
for it, in user settings and a repo's file alike -> an export can carry a project
pinned that way. Agent flags are the one of the four a repo's file cannot carry:
see agents.md. Elsewhere blank = absent, "none" and "no opinion" coming to the same
thing: a field with its own sentinel (agent `none`, shell `login`) would have
two ways to say one thing and lose the distinction next load, an empty hook is
not a hook to trust, an empty file list links nothing. Cost: a stray empty key
on those three fields is an opinion, not a typo.

Repo `.multishell.json` fills only gaps the user left: a team default must
never override a made choice. What it may say (what a worktree opens, whether
that runs the agent, row order) changes only what is drawn -> needs no trust,
unlike a hook.

Its hooks run code someone else committed -> one-time yes, held against the
sha256 of the file's bytes, asked when the user selects one of that project's
worktrees. Re-read when mtime moves. Answer kept per file, sixteen of them:
the file is tracked so it differs per branch, and one shared answer would be
asked again on every switch. Asked of the model as `model.effectiveSettings(for:)` and
`model.worktreeSettings(for:)`; the override forms are the exception, through
`model.settings(of:)`, where blank has to keep meaning "follow the global".
Costs: layering must be asked of the model, never `project.settings`; a trust question can arrive without a click; editing any
other key re-asks; a yes outlives the file.

Export writes the settings in force back over the repository's file, and a
hook the user refused is not in force -> exporting would have dropped a
teammate's committed hook silently. So export keeps the file's own hooks where
the user wrote none, and records trust only where every hook written is the
user's own words; a refused hook stays refused against the new digest, so
nothing asks again about a decision already made.

Grey in a hook editor = inherited, nothing else. Odd shapes, each from a bug:
no prefix on an existing branch; blank worktree directory = the default; `.`,
`..` and an empty slug -> `_`; whitespace-only hook = "none".

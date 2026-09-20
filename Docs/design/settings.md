# Settings

Layering of user, project and repository settings, and the trust that guards a
shipped hook. Newest at the bottom.

- **Project over global; `nil` follows the global.** Blank means absent, since
  "none" and "no opinion" come to the same thing and a second sentinel would
  lose the distinction next load.
- **Four fields take blank as "none"**: worktree path, branch prefix, default
  branch, agent flags. They have no other spelling for it. Cost: a stray empty
  key there is an opinion, not a typo.
- **A repo's `.multishell.json` fills only gaps the user left.** A team default
  must never override a made choice. Agent flags are the one field it cannot
  carry (agents.md).
- **What it draws needs no trust; what it names on disk does.**
  `worktreeDirectory`, `linkedPaths` and `copiedPaths` are paths on the reader's
  machine, not pixels.
- **"Runs nothing, so needs no trust" was wrong.** A repo could commit
  `worktreeDirectory: ~/.claude/skills` with a `SKILL.md` and install a global
  agent skill on any create, or link `~/.ssh/id_ed25519` into a tree an agent
  reads.
- **So a repo's three are confined to the checkout**, once at read time and held
  on the project, the sidebar asking per row per render. The tick's reader
  confines off the main actor with the parse; export does it on the main actor.
- **The directory resolves symlinks**, so a committed link cannot carry it out.
- **The lists are resolved lexically and must land strictly under the root**,
  the file not being there yet. `..` is resolved, never counted, so no spelling
  of it has to be anticipated.
- **Three guards come first**, or the resolve would land inside:
  `appendingPathComponent` takes `/etc/passwd` as relative, `~` is not expanded,
  and a leading `$` is refused because nothing runs a shell.
- **A refused value is dropped whole and the user's stands.** Pointing outside
  is the user's to do in settings, not the repository's. Cost: a repo can no
  longer ship `../{project}-worktrees`, and the drop is silent.
- **The rule reaches only what the file ships.** `place` takes
  `heldToRepository`, false for a user's list, whose source end is used as
  written. The destination end is held for everyone, mirroring the entry.
- **A list is wholly one or the other.** `layered` takes the repo's only where
  the user's is blank, so a create decides it once and carries it on the value
  as `WorktreeFileList`.
- **A create re-confines against the disk** before `git worktree add`: a branch
  can commit the symlink without changing the bytes that were read, so the mtime
  never moves and the cached yes stands.
- **Confinement is not enough.** `copiedPaths: .aws.json` names something inside
  the checkout, and a gitignored `.aws.json` there is not the repo's to ask for.
  So all three wait for the one-time yes the hooks wait for.
- **The question is built from the confined value**, so the dialog never offers
  to trust a line it could not turn on, and a file whose every path is refused
  asks nothing.
- **The stored answer's key is still `sharedHooks`.** Renaming it would drop
  every answer already given.
- **Trust is per file, held against the sha256 of its bytes**, asked when a
  worktree of that project is selected and re-read when mtime moves. An answer
  is kept per file: the file is tracked, so one shared answer would be asked
  again on every branch switch.
- **Layering is asked of the model**, `effectiveSettings(for:)` and
  `worktreeSettings(for:)`, never `project.settings`. The override forms are the
  exception, where blank must keep meaning "follow the global".
- **The gate is one line.** `layered` drops what the yes covers, the same fields
  the dialog names, then puts the rest over the user's, rather than each field
  asking.
- **The forms read that same view through `inherited`**, or a caption saying
  "from .multishell.json" names a value the layering left out, which it did for
  an untrusted `worktreeDirectory`.
- **Export writes the settings in force back over the file**, but keeps the
  file's own words where the user wrote none, or exporting would silently drop a
  teammate's committed hook.
- **Export carries the trust answer to the new digest**, and records none where
  none was given. Comparing the two alone made trusting a file and then
  exporting it revoke the yes.
- **`keeping(from:)` covers every gated field, not the hooks alone.** Gating the
  directory and the lists on trust blanked them for an untrusted file, and
  export then wrote the file without those keys at all.
- **Grey in a hook editor means inherited, nothing else.**
- **Odd shapes, each from a bug**: no prefix on an existing branch; blank
  worktree directory is the default; `.`, `..` and an empty slug become `_`; a
  whitespace-only hook is "none".
- **Export puts the fields over the file's keys, never rebuilds the file.** A
  key this build has no field for, a `$schema` line, a newer build's order and a
  wrong-typed value all survive. Cost: the wrong type stays until someone who
  can read it changes it.
- **Help goes behind an (i).** Captions doubled every form's height and were
  read once. A caption is left only for a value computed live.
- **Which states raise a banner is three toggles, not one picker.** The picker
  offered three of the eight answers and could not say "only when something
  failed", which is the whole of what some people want.
- **Cost of that**: a state file written by this build reads as off on a build
  with the picker. One caption at the foot holds whichever toggles are on, where
  three (i) buttons said it three times.
- **Permission is asked as the toggle goes on**, not at the first report, so the
  dialog arrives while the user is looking at the thing it is about and a
  refusal can be answered where it is read.
- **The answer is runtime state**, re-read as the page opens and as the app
  returns to the front, that being the way back from the settings the caption
  points at.

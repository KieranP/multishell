# Settings

- **Project over global; `nil` follows the global.** Blank means absent, since
  "none" and "no opinion" come to the same thing and a second sentinel would
  lose the distinction next load.
- **Four fields take blank as "none"**: worktree path, branch prefix, default
  branch, agent flags. They have no other spelling for it. Cost: a stray empty
  key there is an opinion, not a typo.
- **A repo's `.multishell.json` fills only gaps the user left.** A team default
  must never override a made choice. Of those four, agent flags are the one it
  cannot carry (agents.md).
- **What it names on disk needs trust; what it draws does not.** "Runs nothing,
  so needs no trust" was wrong: `worktreeDirectory`, `linkedPaths` and
  `copiedPaths` are paths on the reader's machine. A repo could commit
  `worktreeDirectory: ~/.claude/skills` with a `SKILL.md` and install a global
  agent skill on any create, or link `~/.ssh/id_ed25519` into a tree an agent
  reads.
- **So a repo's three are confined to the checkout**, once at read time and held
  on the project, since the sidebar asks per row per render. The tick's reader
  confines off the main actor with the parse, and export writes, stamps and
  confines there too: each touches the disk, and on a slow volume would hold the
  window.
- **The directory resolves symlinks**, so a committed link cannot carry it out.
- **Resolved as far as it exists, the rest appended**: the resolver returns a
  path that does not exist unchanged, links and all, and before the first create
  the container never exists. A link to nothing is refused, there being no
  telling where it will lead.
- **The lists are resolved lexically and must land strictly under the root**,
  the file not being there yet. `..` is resolved, never counted, so no spelling
  of it has to be anticipated.
- **Three guards come first**, or the resolve would land inside:
  `appendingPathComponent` takes `/etc/passwd` as relative, `~` is not expanded,
  and a leading `$` is refused because nothing runs a shell.
- **A refused value is dropped whole and the user's stands.** In a list the
  value is the entry, the rest of the list kept. Pointing outside is the user's
  to do in settings, not the repository's. Cost: a repo can no longer ship
  `../{project}-worktrees`, and the drop is silent.
- **Refusal reaches only what the file ships.** `place` takes
  `isRepositoryList`, false for a user's list, whose entry spelled to leave the
  root is skipped and named rather than failing the create (hooks.md), and whose
  symlinked sources may lead anywhere. Both lists take an entry as a path inside
  the repository and mirror it into the worktree; `~` and variables are never
  expanded.
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
  is kept per version of the file: the file is tracked, so one answer per
  project would be asked again on every branch switch.
- **Layering is asked of the model**, `effectiveSettings(for:)` and
  `effectiveWorktreeSettings(for:)`, never `project.settings`. The override
  forms are the exception, where blank must keep meaning "follow the global".
- **The gate is one line.** `layered` drops what the yes covers, the same fields
  the dialog names, then puts the user's over the rest, rather than each field
  asking.
- **The forms read that same view through `inherited`**, or a caption saying
  "from .multishell.json" names a value the layering left out, as it did for an
  untrusted `worktreeDirectory`.
- **An `InheritableSettingKeys` pairs the project field with the file's once.**
  Reading the layering with the override cleared answered only for a field
  merged as `own ?? shared`; any other quietly showed the global.
- **Export writes the settings in force back over the file**, but keeps the
  file's own words where the user wrote none, or exporting would silently drop a
  teammate's committed hook.
- **Export carries the trust answer to the new digest**, records a yes where
  every word the yes covers is the user's own, and none where no answer was
  given. Comparing the two alone made trusting a file and then exporting it
  revoke the yes.
- **`carryingOver(from:)` covers every gated field, not the hooks alone.**
  Gating the directory and the lists on trust blanked them for an untrusted
  file, and export then wrote the file without those keys.
- **Grey in a hook editor means inherited, nothing else.**
- **Odd shapes, each from a bug**: no prefix on an existing branch; blank
  worktree directory is the default; `.`, `..` and an empty slug become `_`; a
  whitespace-only hook is "none".
- **Export puts the fields over the file's keys, never rebuilds the file.** A
  key this build has no field for, a `$schema` line, a newer build's order and a
  wrong-typed value all survive. Cost: the wrong type stays until someone who
  can read it changes it.
- **Integrations is per project with no global and no repository file**: it
  turns display-only reads off, and a repository without the service already
  shows nothing (services.md).
- **Help goes behind an (i).** Captions doubled every form's height and were
  read once. A caption is left only for a value computed live.
- **An (i) holds at most 200 characters once filled in**, leaving what another
  row's (i) says to it. The translation tests and AgentHooksRowTests hold the
  count.
- **A page taller than its window is split, not scrolled.** A grouped form's
  scroller is an overlay, so what is below the fold says nothing, and forcing
  the indicators changes nothing there. Project Hooks shows Create, Delete or
  Environment, six editors being 973 pt of a 600 pt window; Agents shows the
  preferred agent or the hooks, the hooks growing with every agent installed.
- **A hook file opens in a popover**, which inline added 166 pt a row.
- **Which states raise a banner is three toggles, not one picker.** The picker
  offered three of the eight answers and could not say "only when something
  failed", which is all some people want.
- **Cost of that**: a state file written by this build reads as off on a build
  with the picker. One caption at the foot says what holds for every toggle,
  where three (i) buttons said it three times.
- **Permission is asked as the toggle goes on**, not at the first report, so the
  dialog arrives while the user is looking at the thing it is about and a
  refusal can be answered where it is read.
- **The answer is runtime state**, re-read as the page opens and as the app
  returns to the front, the way back from the settings the caption points at.
- **Export stores its trust answer before the write**, the digest being known
  from the bytes. Stored after, a poll reading the file in between asked the
  user to trust hooks they had just exported, and nothing withdrew it.
- **Exports land in the order they were asked**, through the `SaveOrder` ticket
  the store's saves use, one order per project. Two on a slow volume otherwise
  landed backwards, the older overwriting the newer, and a late finish recorded
  the older's bytes, even with the newer still being written.
- **An editor's tab turns to its worktree through `select`, as a click does.**
  It selected through the store and skipped the question, so a tab opened in
  another project's worktree ran with that file unasked about
  (AppModelSharedSettingsTests).
- **`config project set` decodes the new settings back before it saves them**,
  and refuses a value the decoder would drop or change: a blank agent id, a tint
  off the palette, `null` on a hook, which has no global to follow. Saved as
  given, it would read as unset on the next load. The trust answers are not
  settable there at all (agents.md; AppModelControlProjectSettingsTests).

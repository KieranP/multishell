# State, settings and the command line

What a command-line request, a persisted field, a setting or runtime state needs
beyond the code itself.

- **A command-line request.** A case in `ControlRequest`, its answer in the
  model's `reply(to:)`, which the compiler holds total, its parsing in its
  group's file under the helper's `Control/`, its arguments in the group's file
  under `Usage/` and its word in the group's line of the overview `usage`, which
  HelperUsageTests checks. The model's side is tested in its AppModelControl
  suite through the fake channel.
- **A request's alerts are made in its own task**: an alert records the request
  whose task made it, and only that request answers with it and takes it down.
  Work handed to `Task.detached` or a queue callback leaves the request's task,
  so its alert stays up unanswered (design/agents/command-line.md).
- **A request over a working agent takes `--force`** and is refused with
  `agentWorking` without it. It never opens the dialog the click would. Any
  other forcing, such as a branch delete git would refuse, gets a flag of its
  own.
- **A request that runs long stops when its task is cancelled**, which the
  helper hanging up does. A stopper it holds is stopped from a
  `withTaskCancellationHandler`, as a create's is.
- **A new refusal** is a case in `ControlRefusal` and its English in the
  helper's `ControlRefusal+Wording`, naming the command that gets past it where
  there is one; the app's catalogue takes none (design/translation.md).
- **A new command group is a case of `ControlCommand`**, and the compiler then
  asks for its branch in `runControl` and its text in `usage(of:)`.
  HelperUsageTests asks for its line in the overview `usage` once it has
  subcommands.
- **A key `panes key` names** goes in `ControlKey.names` and in the engine's
  `namedKeyCodes`. Nothing forces the second: a name with no code stops the
  press there, the keys before it already sent, and the request is refused as
  `paneNotLive`.
- **A persisted field.** Decode with a default, an unknown enum value included,
  and add a decoding case to that type's own tests.
- **The verb carries the choice**: the strict decode where a wrong type should
  fail the file, the tolerant one where a value this build cannot read must cost
  that value alone. A lossy array drops a broken element; projects stay strict.
- **A field on `Project`** also needs its case in that type's hand-written
  coding keys, `==` and `hash`, which keep this run's read of a repo's file out
  of all three. ProjectTests lists the fields.
- **A field on `ProjectSettings`** needs a case in its hand-written coding keys,
  which keep the shell, the auto-start pair and the trust answers under their
  old keys; one left out is never saved. ProjectSettingsTests counts them.
- **A field on `Workspace`** needs a case in its hand-written coding keys too,
  which keep the shell, the auto-start pair, the worktree names, the
  notification preference and the hook timeout under their old keys.
  WorkspaceTests counts them.
- **A preference.** In order: the field on the workspace, a setter on the store,
  which must sit in that one file beside the private setter, a method on the
  model doing whatever else the change needs, and the row bound through the
  model's setting accessor.
- **A preference also needs a row in `config global`'s key table**,
  `globalSettings`, under its state-file key and through that same setter.
  Nothing forces the row: left out, the command line neither lists nor sets it.
  A project setting needs none, its keys coming from the coding keys.
- **A project override** is a second field on the project settings and a
  resolver reading those first; if a repository may ship it, a shared-settings
  field, a line in the layering and an `InheritableSettingKeys` member pairing
  the two, plus the two trust places if it names a path (design/settings.md).
- **A collection, or a reference between collections.** Extend the repair and
  the invariants. Every store operation must leave the invariants true, and the
  seeded random tests find it if not, printing the seed and step to replay.
- **Runtime state.** On the model, never the workspace. Keyed by worktree it
  also goes in the forget, or it outlives its row and the next worktree at that
  path inherits it (design/worktrees/creating-and-removing.md); keyed by
  project, in the project's removal; keyed by file tab, in `pruneFileTabs`, or a
  closed tab's id keeps its entry for the run. Nothing forces any of the three.
- **A request a view acts on is a model property the view takes** in its update,
  `takeChangeStepRequests` and `takeFileTabFocusRequest` the pattern: a SwiftUI
  bar cannot reach the AppKit view beside it, and the take, read in
  `updateNSView`, is what makes SwiftUI call the update again.
- **A value a poll or timer writes goes through `setIfChanged`**, or every view
  reading it redraws on each tick (design/merged-branch.md).
- **The session states own who clears what**: change it there and in their
  tests, not in a view.
- **A per-build file.** On the variant pattern, so a debug run never touches the
  installed app's state and two worktrees never touch each other's. A file a
  hook reads from outside either stays shared, as the hooks' helper link does,
  or has its path handed over in the environment, as the socket is for a report.
  One the helper finds for itself, as a request finds the socket, takes the
  variant of the bundle the helper sits in, its links followed, since
  `/usr/local/bin` reaches it through the build's own `cli` link
  (state-on-disk.md).
- **A settings row.** Bind through the model's setting accessor, which re-reads
  the stored value; a field with its own binding goes stale against a change
  made elsewhere.
- **An override is an `OverrideRow` in its page's table**, naming the key path
  once, or the `InheritableSettingKeys` where a repository may ship it. Help
  goes behind an (i); a caption is only for a value computed live.
- **A page that outgrows its window gets another part**, a `SettingsSection`
  listed under its page in the sidebar, and each part a line in
  ViewSettingsWindowTests. A row on any page also goes in the page's search
  words, `SettingsPage+SearchTerms`.
- **A notified state.** A toggle in the notification preference, whose subscript
  answers for every state so a caller can hand it whatever was reported, and a
  place in `notifiableStates`, the order the settings page lists them in. It
  also needs a case in the preference's hand-written coding keys, which keep
  Failed under `error`, and a line in its decode; one left out of the keys is
  never saved.

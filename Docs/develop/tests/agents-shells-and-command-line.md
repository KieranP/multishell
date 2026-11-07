# Agents, shells and the command line

Which test catches which breach of the rules for agent reports and hooks, shell
integration, the helper, the socket and control requests. Why each rule holds is
in `design/`.

## What catches a breach of the rules

- **Sidebar counts agree with the columns they summarise**:
  AppModelAgentBoardTests over every state and both filter positions, the counts
  being made without building a card. A pane whose reported agent has exited is
  a shell to the counts, the cards, the strip and its sidebar row alike, the
  four having once asked apart.
- **An agent mark that draws nothing**: AgentMarkShapeTests holds each mark to
  its square; a file that will not parse is left out of the table rather than
  crashing a view.
- **An agent typed at a prompt that marks nothing**: the placeholder test in
  ShellIntegrationScriptsTests holds the generated files to naming the agents,
  and ShellIntegrationScriptsTests+SessionReports runs the real shells. That
  caught a zsh word subscript taking characters for a command run by its path,
  which a syntax check cannot see.
- **A program's OSC 7501 report and an agent's hook both moving a dot**:
  SessionStatesTests+ProgramStatus, with ProgramStatusRecordsTests for what a
  clear takes and GhosttySurfaceEventTests for what the patch's action carries.
- **Remove leaves a hook the user put in our own group**:
  AgentHookIntegrationMergingTests.
- **A comma-decimal locale still sends a report that parses**:
  ShellIntegrationThroughHelperTests under a real zsh, pointing the user
  variable at an empty directory or the chain reaches the developer's own rc
  file.
- **A notification type no build has heard of is taken to ask**:
  AgentHookIntegration+ReportsTests+Events.
- **What a failed accept means**: UnixSocketServer+AcceptOutcomeTests, the
  classification only.
- **A comma-decimal locale gives bash a sane duration**:
  ShellIntegrationThroughHelperTests+Bash sets the clock variable by hand, which
  the system bash leaves unset.
- **Remove writes nothing to a file holding none of ours, and still takes back a
  half-written install**: AgentHookIntegrationInstallAndRemoveTests.
- **A repeat agent report writes nothing observable**:
  AppModelSessionReportsTests, through observation tracking.
- **The worker rules**: SessionStatesTests+BackgroundWorkers, with the roster
  kept by id, an older helper's count read as unnamed workers, and a worker's
  tool calls leaving the roster as it was.
- **A held stop leaves a failure alone** whether a worker's prompt covered it or
  it is still standing, so no failure is paid back as a Done:
  SessionStatesTests+WorkerPrompts.
- **A background shell is held for by pid and ended by its exit**:
  SessionStatesTests+BackgroundShells, and KernelProcessTableTests finds one
  among real children by its command line.
- **A resuming agent's Done is paid once**, by the woken turn or a cancelled
  last worker's end, never with a worker out: SessionStatesTests+ResumingAgents,
  and AppModel+SessionReportsTests+ResumingAgents from the report source up.
- **An agent dying with its shell announces nothing in either sweep order**:
  AppModelPIDWatchTests over twelve pairs, so a set's order meets both.
- **Each agent names a worker in its own spelling**:
  AgentHookIntegration+ReportsTests+Events. A start or stop naming nobody counts
  as an unnamed one: AgentHookEventTests.
- **A worker that is a conversation of its own is a worker, and its Stop is not
  the pane's Done**: AppModel+SessionReportsTests+CopilotWorkers, from captured
  payloads.
- **No value in a custom command or editor line is run**, inside the user's
  quotes or out: ShellLineTests under five real shells and each installed fish.
- **The plugin follows a child session**: OpenCodePluginTests runs the generated
  JavaScript's `setup` against a fake context with spawn replaced, since a
  source test passes whatever it was rewritten to. Its bus queues events as
  OpenCode's does, waiting on no handler, and each step waits one turn of the
  loop, so a step's reports land before the next.
- **The chip reads the same roster on the row and on the card**, and a Done
  gives way to a worker and comes back once: AppModelSessionReportsTests.
- **The login environment is not known before its PATH has been scanned**:
  AppModelLoginEnvironmentTests, using the system shells file so the check is
  independent of which agents the machine has.
- **bash keeps its debug trap against one installed at the first prompt**,
  chains to both and hands the last status on:
  ShellIntegrationThroughHelperTests+Bash, real bash driven through a pipe so
  the prompt command runs between the two.
- **A PIPE trap set after the init survives the next report**, and **a refused
  relay's read loop ends with its shell** though a background child holds the
  pipe: HelperRelayTests under each installed bash.
- **A launched command is given no pipes**, so a shim holding the editor open
  holds no descriptors: ShellCommandTests.
- **A duration no clock could have produced is dropped coming off the channel**:
  SessionStateReportBoundsTests and ElapsedTextTests, the trap being a
  conversion outside its range.
- **A placeholder inside a value is not expanded again**: AgentFlagsTests.
- **A branch in a flag runs nothing on the way to the agent**: TabCommandTests
  under sh, zsh, bash and tcsh.
- **A live socket whose accept backlog is full is not taken for a dead one**:
  UnixSocketServerTests. The same suite starts a live server twice and fails a
  start, each time with a second process trying the claim, since a process's own
  record locks never conflict, and holds the path limit to the staging name's.
- **A request is answered on its own connection, a report or an unknown request
  never**: SocketMessageSourceTests. **An answer sent after the client's EOF
  still arrives, and one held open runs the client out of time, one that stops
  reading holds up no other, and one read slowly but steadily arrives whole past
  the timeout**: SocketReplyTests. **A request nobody reads runs out of time
  while still being sent, and a timeout under a second still runs out**:
  UnixSocketClientTests.
- **The command line reaches its own build's app**: HelperControlTests and
  PathsVariantTests, the latter also giving two worktree names that start alike
  files of their own; PathsStateFileCarryOverTests carries over a state file
  saved under the cut name from before the hash. **The installed tool is offered
  only over nothing, a dangling link or the shared one**: HelperLinkTests. **A
  link that cannot be made leaves the shell integration written**:
  AppLaunchFilesTests.
- **`open` launches the bundle the helper is in and waits for its answer**:
  HelperAppCommandsTests, through a stand-in for `/usr/bin/open` named by
  `MULTISHELL_OPENER`, a debug build's alone, since a test may not launch an
  app.
- **`multishell` in a pane is the helper, not the app**: SessionEnvironmentTests
  orders PATH, HelperHandOffTests the app's own hand-off, through a link to its
  executable too. **A login profile moving `/etc/paths` ahead leaves ours in
  front**: ShellIntegrationScriptsTests+LeadingPath under zsh, each bash and
  fish, and TabCommandTests for an agent's line through each login shell.
- **Each request does what its menu item or click does, and is refused rather
  than asked over a working agent**: the AppModelControl suites, the worktree
  and project ones on real git. Typing reaching a real shell needs the engine,
  so it was run by hand against a debug build on a scratch home
  (build/verifying-a-change.md), as were a pane's text read, the window and pane
  screenshots, and the settings windows' identifiers.
- **Two requests' alerts each answer their own request, and the user's comes
  back**: AppModelControlRequestAlertsTests, which also files nothing for an
  alert raised under a request that has answered.
- **A wait returns once the pane gets there and says how long it waited when it
  does not**: HelperPaneWaitingTests. **Following prints each new sample once
  and stops at the count**: HelperDebugSamplesTests, and AppModelDebugToolsTests
  numbers on from the last sample when the tools go off and on. **A screenshot
  is written by the helper**: HelperDebugScreenshotTests. **A find prints once
  the engine has counted**: HelperPaneFindingTests, and AppModelControlFindTests
  for the count's way from the engine to the model. Pressing Ctrl+C, a find's
  count and the menu were run by hand against a debug build.
- **A pane caught mid-resize is placed in a screenshot at its surface's own size
  from the top left**, as the layer shows it, not stretched:
  ViewScreenshotTests.
- **A key the command line presses types what that key types**:
  GhosttyKeyInputControlKeyTests, skipped rather than failed under any layout
  but US, its texts being that layout's.
- **The pid the helper reports stops short of the app**:
  HelperSessionEnvironmentTests with two real shell layers under the test
  process posing as the app; ProcessAncestryTests has the walk on its own.
- **The model's half**: AppModelSessionReportsTests, a report naming the app's
  pid tracking none, beside one from a subdirectory marking the deepest worktree
  containing it.
- **A worktree path holding a control character still reports from zsh**:
  ShellIntegrationThroughHelperTests. bash is not exercised, going through the
  helper, which encodes.
- **A user-set shell directory variable is followed**:
  ShellIntegrationScriptsTests+UserStartupFiles, a login interactive zsh under a
  fake home. Only a login shell reads the profile, so the login flag is what the
  test is.
- **It inherits no session or socket**: `Detached` hands the shell its whole
  environment, and run from a Multishell tab an inherited pair reported to the
  developer's live app.
- **An empty Enter under a user's prompt command starts no command**:
  ShellIntegrationScriptsTests+SessionReports.
- **A dead agent with a worker counted no longer holds Working**, and its
  shell's later failure is not an agent waiting on the badge:
  SessionStatesTests+BackgroundWorkers in both orders, AppModelDockBadgeTests
  with the board closed.
- **A greeting holding an equals sign does not cost the login shell its first
  variable**: EnvironmentDumpParserTests.
- **Numbers in an agent's settings file come back as written**, and a literal
  the grammar refuses or bytes that are not UTF-8 are still refused untouched:
  AgentHookFileTests.
- **What a zsh prompt tells the terminal now the engine's integration is off**,
  a command's end and status, the directory, the title and the cursor shape in
  each keymap, each only where the user's features ask:
  ShellIntegrationScriptsTests +PromptMarks, +DirectoryReports, +Title and
  +CursorShape, run through +ZshOutput, which loads zle by hand for the keymap
  hooks a piped shell would not register. bash's marks, directory and title run
  through +BashOutput, and fish's cursor through +FishOutput.
- **bash launched as libghostty launches a command**, `exec -l`, still reading
  our init file: EngineCommandLineTests.
- **`sudo` and `ssh` wrapped only where the user's features ask, and a `sudo`
  function of their own kept**: ShellIntegrationScriptsTests +CommandWrappers,
  the bash half under `InstalledBashes.all` and the fish half under
  `InstalledShells.fishes`.
- **The close guard and the quit alert count only an agent's Working**, so a
  plain command asks nothing: AppModelSessionReportsTests and
  AppModelTabClosingTests.
- **A misspelt option in a hook line is a usage error** for every reporting
  command, not a value read under another name: HelperTests.

# Agents, shells and the command line

Which test catches which breach of the rules for agent reports and hooks, shell
integration, the helper, the socket and control requests. Why each rule holds is
in `design/`.

## What catches a breach of the rules

- **Sidebar counts agree with the columns they summarise**:
  AppModelAgentBoardTests. A pane whose reported agent has exited is a shell to
  the counts, the cards, the strip and its sidebar row alike, the four having
  once asked apart.
- **An agent mark that draws nothing, or crashes a view on a file that will not
  parse**: AgentMarkShapeTests.
- **An agent typed at a prompt that marks nothing**:
  ShellIntegrationScriptsTests and its +SessionReports, which runs the real
  shells. That caught a zsh word subscript taking characters for a command run
  by its path, which a syntax check cannot see.
- **A program's OSC 7501 report and an agent's hook both moving a dot**:
  SessionStatesTests+ProgramStatus, ProgramStatusRecordsTests and
  ProgramStatusGhosttyActionTests.
- **Remove leaves a hook the user put in our own group**:
  AgentHookIntegrationMergingTests. **It writes nothing to a file holding none
  of ours, and still takes back a half-written install**:
  AgentHookIntegrationInstallAndRemoveTests.
- **A comma-decimal locale's report and duration**:
  ShellIntegrationThroughHelperTests under a real zsh, pointing the user
  variable at an empty directory or the chain reaches the developer's own rc
  file, and its +Bash, which sets the clock variable by hand, the system bash
  leaving it unset.
- **A notification type no build has heard of is taken to ask**:
  AgentHookIntegration+ReportsTests+Events.
- **What a failed accept means**: UnixSocketServer+AcceptOutcomeTests, the
  classification only.
- **A repeat agent report writes nothing observable**:
  AppModelSessionReportsTests.
- **A worker's roster, a held stop, a background shell and a resuming agent's
  Done**: SessionStatesTests +BackgroundWorkers, +WorkerPrompts,
  +BackgroundShells and +ResumingAgents, with KernelProcessTableTests finding a
  background shell among real children and
  AppModel+SessionReportsTests+ResumingAgents from the report source up.
- **An agent dying with its shell announces nothing in either sweep order**:
  AppModelPIDWatchTests over twelve pairs, so a set's order meets both.
- **Each agent names a worker in its own spelling**:
  AgentHookIntegration+ReportsTests+Events and AgentHookEventTests. **A worker
  that is a conversation of its own**:
  AppModel+SessionReportsTests+CopilotWorkers, from captured payloads.
- **No value in a custom command or editor line is run**: ShellLineTests under
  five real shells and each installed fish.
- **The OpenCode plugin follows a child session**: OpenCodePluginTests runs the
  generated JavaScript against a fake context, since a test of the source passes
  whatever it was rewritten to. Its bus queues events as OpenCode's does,
  waiting on no handler.
- **The chip reads the same roster on the row and on the card**:
  AppModelSessionReportsTests.
- **The login environment is not known before its PATH has been scanned**:
  AppModelLoginEnvironmentTests, using the system shells file so the check is
  independent of which agents the machine has.
- **bash keeps its debug trap against one installed at the first prompt**:
  ShellIntegrationThroughHelperTests+Bash, real bash driven through a pipe so
  the prompt command runs between the two.
- **A PIPE trap set after the init, and a refused relay's read loop**:
  HelperRelayTests under each installed bash.
- **A launched command is given no pipes**, so a shim holding the editor open
  holds no descriptors: ShellCommandTests.
- **A duration no clock could have produced is dropped coming off the channel**:
  SessionStateReportBoundsTests and ElapsedTextTests, the trap being a
  conversion outside its range.
- **A placeholder inside a value is not expanded again**: AgentFlagsTests. **A
  branch in a flag runs nothing**: TabCommandTests under sh, zsh, bash and tcsh.
- **A live socket whose accept backlog is full is not taken for a dead one**:
  UnixSocketServerTests, which also holds the path limit to the staging name's
  and checks the listener closes at exec. Each claim is tried from a second
  process, since a process's own record locks never conflict.
- **A request is answered on its own connection, a report never**:
  SocketMessageSourceTests. **A reply's timing, and an answer a child holds
  open**: SocketReplyTests and UnixSocketClientTests.
- **The command line reaches its own build's app**: HelperControlTests,
  PathsVariantTests and PathsStateFileCarryOverTests. **The installed tool's
  link**: HelperLinkTests and AppLaunchFilesTests.
- **`open` launches the bundle the helper is in and waits for its answer**:
  HelperAppCommandsTests, through a stand-in for `/usr/bin/open` named by
  `MULTISHELL_OPENER`, a debug build's alone, since a test may not launch an
  app.
- **`multishell` in a pane is the helper, not the app**: SessionEnvironmentTests
  and HelperHandOverTests. **A login profile moving `/etc/paths` ahead leaves
  ours in front**: ShellIntegrationScriptsTests+LeadingPath and TabCommandTests.
- **Each request does what its menu item or click does, and is refused rather
  than asked over a working agent**: the AppModelControl suites, on real git.
  Typing reaching a real shell needs the engine, so it was run by hand against a
  debug build on a scratch home (build/verifying-a-change.md), as were a pane's
  text read, the window and pane screenshots, and the settings window's
  identifier.
- **Two requests' alerts each answer their own request**:
  AppModelControlRequestAlertsTests.
- **The helper's waits, samples, screenshots and finds**:
  HelperPaneWaitingTests, HelperDebugSamplesTests, AppModelDebugToolsTests,
  HelperDebugScreenshotTests, HelperPaneFindingTests and
  AppModelControlFindTests. Pressing Ctrl+C, a find's count and the menu were
  run by hand against a debug build.
- **A pane caught mid-resize is placed in a screenshot unstretched**:
  ViewScreenshotTests.
- **A key the command line presses types what that key types**:
  GhosttyKeyInputControlKeyTests, skipped rather than failed under any layout
  but US, its texts being that layout's.
- **The pid the helper reports stops short of the app**:
  HelperSessionEnvironmentTests with two real shell layers under the test
  process posing as the app, ProcessAncestryTests, and for the model's half
  AppModelSessionReportsTests.
- **A worktree path holding a control character still reports from zsh**:
  ShellIntegrationThroughHelperTests. bash is not exercised, going through the
  helper, which encodes.
- **A user-set shell directory variable is followed**:
  ShellIntegrationScriptsTests+UserStartupFiles, a login interactive zsh under a
  fake home, since only a login shell reads the profile. It inherits no session
  or socket: `Detached` hands the shell its whole environment, and run from a
  Multishell tab an inherited pair reported to the developer's live app.
- **A bash started in a pane inherits none of our prompt hooks**:
  ShellIntegrationScriptsTests+UserStartupFiles. **An empty Enter under a user's
  prompt command starts no command**: its +SessionReports.
- **A dead agent with a worker counted no longer holds Working**:
  SessionStatesTests+BackgroundWorkers in both orders, AppModelDockBadgeTests
  with the board closed.
- **A greeting holding an equals sign does not cost the login shell its first
  variable**: EnvironmentDumpParserTests.
- **An agent's settings file comes back as written, or is refused untouched**:
  AgentHookFileTests.
- **What a zsh, bash or fish prompt tells the terminal now the engine's
  integration is off**: ShellIntegrationScriptsTests +PromptMarks,
  +DirectoryReports, +Title and +CursorShape, through +ZshOutput, +BashOutput
  and +FishOutput. +ZshOutput loads zle by hand for the keymap hooks a piped
  shell would not register.
- **bash launched as libghostty launches a command**, `exec -l`, still reading
  our init file: EngineCommandLineTests.
- **`sudo` and `ssh` wrapped only where the user's features ask**:
  ShellIntegrationScriptsTests+CommandWrappers.
- **The close guard and the quit alert count only an agent's Working**:
  AppModelSessionReportsTests and AppModelTabClosingTests.
- **A misspelt option in a hook line is a usage error**, not a value read under
  another name: HelperTests. `agent-hook` exits 0 whatever it is given.

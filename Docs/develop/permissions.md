# Permissions macOS asks for

- **An alert provoked by a command in a pane names Multishell**, macOS holding
  the spawning app responsible.
- **The app asks for two things of its own**: Notifications, when a notification
  is turned on in Settings or by `multishell config global set`, and an
  administrator's password to link the CLI into `/usr/local/bin`. A build offers
  the install only where that link is missing, dangling or names the shared one,
  so a debug build does not ask while the installed app's tool is linked.
- **Two places say what a pane may ask for**: the usage strings in the
  Info.plist template, and the entitlement beside them in the entitlements file
  where the hardened runtime has one. Extend both when a pane reaches somewhere
  new.
- **TCC reads this app's entitlements for what a pane asks**, not only the
  asking process's (design/signing.md).
- **What a missing string costs depends on the service.** A folder is denied
  with no reason named; the device services kill the process that asked, with a
  privacy-violation abort and nothing shown.
- **An empty string counts as missing.** `InfoPlistTemplateTests`
  `theMicrophoneUsageStringIsDeclaredInTheBundleTheScriptWrites` holds the
  microphone's to having words, a pane's dictation being the common case.
- **A grant is keyed to the designated requirement**, so an ad-hoc build's bare
  cdhash loses every permission at each rebuild. A record the requirement no
  longer matches is ignored, so a changed identity is asked about again.
- **`codesign -d -r-` on the bundle says what it will be remembered by**, and
  the `com.apple.TCC` subsystem in the unified log says which command actually
  asked.
- **`AUTHREQ_ATTRIBUTION` names the accessing process** beside the responsible
  one. Service names are the log's less the `kTCCService` prefix.
- **App Management, Full Disk Access, Accessibility, Input Monitoring and Screen
  Recording are granted only by hand in System Settings.** The last three can
  raise an alert, which only opens Settings; the first two are only denied.
- **App Management is the one working on this app needs**: anything a pane runs
  that writes inside an app bundle wants it, a `make install` of this app
  included. Its service name is `SystemPolicyAppBundles`.
- **A pane driving the keyboard or taking a screenshot wants one of the other
  three**, under this app's name.
- **`multishell debug screenshot` and `panes type` or `panes key` want none of
  them**: the app draws its own views and hands the keys to libghostty, never
  capturing the screen or posting an event; design/agents.md for the screenshot,
  design/terminals.md for the keys.
- **`tccutil reset <service> <bundle id>` is for a remembered no.**

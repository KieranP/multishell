# Permissions macOS asks for

- **An alert provoked by a command in a pane names Multishell**, macOS holding
  the spawning app responsible.
- **Two places say what a pane may ask for**: the usage strings in the
  Info.plist template, and the entitlement beside them in the entitlements file
  where the hardened runtime has one. Extend both when a pane reaches somewhere
  new.
- **TCC reads this app's entitlements for what a pane asks**, not only the
  asking process's; signing.md records the test.
- **What a missing string costs depends on the service.** A folder is denied
  with no reason named; the device services kill the process that asked, with a
  privacy-violation abort and nothing shown.
- **A grant is keyed to the designated requirement**, so an ad-hoc build's bare
  cdhash loses every permission at each rebuild. A record the requirement no
  longer matches is ignored, so a changed identity is asked about again.
- **`codesign -d -r-` on the bundle says what it will be remembered by**, and
  the TCC subsystem in the unified log says which command actually asked.
- **`AUTHREQ_ATTRIBUTION` names the accessing process** beside the responsible
  one, which is always this app. Service names are the log's less the
  `kTCCService` prefix.
- **App Management, Full Disk Access, Accessibility, Input Monitoring and Screen
  Recording are never prompted for**, only denied, so they are added by hand in
  System Settings.
- **App Management is the one this app needs itself**: anything a pane runs that
  writes inside an app bundle wants it, a `make install` of this app included.
- **A pane driving the keyboard or taking a screenshot wants one of the other
  three**, under this app's name.
- **`tccutil reset <service> <bundle id>` is for a remembered no.**

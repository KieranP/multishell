# Signing a local build

Why a dev certificate, a hardened runtime and this entitlement set. Newest at
the bottom.

- **A local build is signed by a certificate, not ad hoc.** A grant is keyed to
  the designated requirement, and an ad-hoc one is a bare cdhash, so every build
  asked again for everything and a ticked box denied in silence.
- **Disclaiming the child instead would mean owning the pty spawn**, and the
  name would then be an unsigned binary, which TCC refuses rather than asks
  about. Cost: a setup step before the first build.
- **Without the certificate the script signs ad hoc and says so**, a fresh clone
  still having to build. Where signing with it fails it says why first, a silent
  fall back being what the certificate exists to avoid.
- **The hardened runtime is on a local build, not saved for release.**
  Notarisation requires it, and turning it on now means a local build runs under
  what a notarised one will rather than meeting it at release.
- **It costs the build nothing.** The app links no third-party dylib, libghostty
  being static, so library validation has nothing to refuse, and the designated
  requirement is unchanged, so existing grants survive.
- **One entitlement is this app's own**, for the AppleScript that links the CLI
  into `/usr/local/bin`, the one Apple event it sends.
- **The rest are for a pane**: audio input, Bluetooth, camera, USB, contacts,
  calendars, location, photo library. A coding agent takes dictation, a CLI
  reads a calendar or flashes a board, and macOS holds this app responsible.
- **On the documented reading none of those is needed**, an entitlement being
  checked against the process making the call. That reading is wrong.
- **The test that settled it**: two copies of the bundle with different
  identifiers, one holding the pane set and one not, each reading the Photos
  library from a pane. The first prompted, naming itself; the second was refused
  and never asked.
- **So TCC consults the responsible app's entitlements**, and a terminal holding
  none of these quietly denies its panes a service the user was never asked
  about.
- **Holding an entitlement permits asking and grants nothing**, the answer still
  being the user's. iTerm2 and Ghostty declare much the same list.
- **The set is every Resource Access entitlement Xcode defines but printing**,
  read out of its own capability list. `com.apple.security.print` is a sandbox
  key with no privacy prompt behind it, so an unsandboxed pane prints without
  it.
- **The `cs.` group is deliberately absent.** JIT, unsigned executable memory,
  library validation and dyld variables are about this app's own code: no JIT
  symbols, no third-party dylib, nothing setting dyld variables. A child's JIT
  is the child's business.
- **Usage strings go further than the entitlements.** The file locations, the
  local network, the media library, speech recognition, a system setting, a file
  provider's files and Focus status have a string and no entitlement to hold.
- **Calendars and reminders carry the legacy key and the newer split both**,
  because the string shown is the responsible app's and the asking CLI may be
  linked against either SDK.
- **The two mechanisms do not substitute.** An entitlement is in the signature
  and says what may be asked for; a usage string is data in the bundle and is
  the sentence in the alert. The missing string is the one that kills the asker.
- **A debug build is signed with `get-task-allow` as well**, added to a copy of
  the file rather than kept in the tree, because a release carrying it is
  refused notarisation.
- **Without it the runtime denies the debugger outright**: lldb refuses to
  attach to a binary signed with the runtime and runs the same binary signed
  without it. The helper takes the same file in a debug build for that one key.
- **A timestamp goes on only for a Developer ID identity**, being a call to
  Apple's server that a local build would fail offline for nothing.

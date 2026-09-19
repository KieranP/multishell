# Bugs

Open findings, numbered from the whole-repo review of 2026-09-13; numbers are
never reused and a fixed entry is taken out rather than kept. The whole-repo
review of 2026-09-16, one reader per layer over every file in full and a second
over each High and Medium, numbered 88 to 122; every one of those was fixed by
2026-09-17. "Unproven" is behaviour nobody has shown, kept because the fix is
cheap or the cost is high.

| #   | Effect   | What                                                                             |
| --- | -------- | -------------------------------------------------------------------------------- |
| 86  | Low      | An OpenCode server reused by a second pane lands the dot on the first pane's tab |
| 87  | Low      | CI never runs `make-app.sh`, so bundling and signing can break with it green     |
| 85  | Unproven | Three of the four agents' hook files have never been watched moving a dot        |

## Scripts and build

### 87. Low. CI never runs `make-app.sh`, so bundling and signing can break with it green

`.github/workflows/ci.yml:12`. CI runs `swift build` and `swift test` for both
packages and nothing else, while `make build` goes on to `Scripts/make-app.sh`
(Makefile:26), which writes the generated Info.plist (make-app.sh:98) and signs
the bundle (make-app.sh:172). A change that breaks any of those passes CI, and
nothing notices until someone runs `make build`. The Makefile's own header at
line 2 says the two are meant not to drift.

## Agents and session state

### 85. Unproven. Three of the four agents' hook files have never been watched moving a dot

`Sources/MultishellCore/Integrations/Agents/AgentHooks.swift`. The four hook
files are written from each agent's documented shape, and only Claude Code's has
been watched moving a dot in a real session. Run each agent once: check its
events fire, that the pid reported is the agent and not a wrapper outliving the
hook, and that Codex's `/hooks` trust holds. The OpenCode plugin
(OpenCodePlugin.swift) has been driven against a stub helper; unproven is that
OpenCode loads a plugin exporting a function rather than a default
`{ id, setup }`, its loader having two generations of that contract, and that
the two permission events arrive under the names the plugin now listens for,
with the title where it reads it.

### 86. Low. An OpenCode server reused by a second pane lands the dot on the first pane's tab

`Sources/MultishellCore/Integrations/Agents/OpenCodePlugin.swift:31`. The plugin
spawns the helper from the OpenCode server's process, and the helper reads
`MULTISHELL_SESSION` from its environment (Helper.swift:13). An OpenCode server
started from one pane and reused by another therefore reports that first pane's
session, so the dot lands on the wrong tab. Only the plugin has this: every
other agent's hook runs in the session's own process.

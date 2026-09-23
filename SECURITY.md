# Security

## Reporting a vulnerability

Report privately through GitHub: the Security tab of
[KieranP/multishell](https://github.com/KieranP/multishell/security/advisories),
"Report a vulnerability". Please do not open a public issue for one.

Include what an attacker gets, the steps that got you there, and the build you
saw it on: the version string is under Multishell, About Multishell, and it
names the commit.

There is no service to attack. Multishell runs on your own machine, and what it
touches is on your own machine. This is one person's project worked on in spare
time, so a report is read when it is read; there is no response time to hold me
to and no bounty.

## What counts

The app spawns shells, reads and writes files in your repositories, runs hooks
from a project's `.multishell.json`, and listens on a unix socket in
`~/Library/Application Support/Multishell/` for agent state reports. What would
interest me:

- Anything a cloned repository can make happen without a click. A hook from a
  `.multishell.json` someone else committed is meant to need the trust prompt
  first; see `Docs/design/settings.md`.
- Anything a local process can do through the socket beyond reporting state, or
  a report that reaches somewhere it should not. See `Docs/design/agents.md`.
- Reading or writing outside the worktree from a branch name, a path or a theme
  file.
- A privilege escalation out of the one script that asks for administrator
  rights, which links the `multishell` CLI into `/usr/local/bin`.

Out of scope: a command you typed into a pane doing what you typed, and the
absence of notarisation, which COMPAT.md already states.

## Supported versions

The latest commit on `main`. There is no release to patch yet.

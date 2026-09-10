# Signing a local build

Why a dev certificate rather than ad hoc.
Newest at the bottom.

## A local build is signed by a certificate, not ad hoc

macOS holds the spawning app responsible for what a process reads -> an alert
about a command in a pane names Multishell; hence the usage strings in the
Info.plist, the only place that can say a command asked. And hence a
certificate rather than ad hoc: a grant is keyed to the signature's designated
requirement, and an ad-hoc one is a bare cdhash, so every build asked again for
everything and a box already ticked denied in silence. Disclaiming the child
instead would mean owning the pty spawn, and the name would then be an unsigned
binary, which TCC refuses rather than asks about. Cost: a setup step before the
first build, a certificate nothing else trusts.

# Permissions macOS asks for

What is prompted for, what is only denied, and how to read the log.

## Permissions macOS asks for

An alert provoked by a command in a pane names Multishell, macOS holding the
spawning app responsible. The usage strings in `make-app.sh`'s Info.plist are
the only place that can say otherwise; extend them when a pane reaches
somewhere new.

A grant is keyed to the signature's designated requirement, so an ad-hoc
build's bare cdhash loses every permission at each rebuild. What a build will
be remembered by, and which command actually asked:

    codesign -d -r- build/Multishell.app
    log show --last 1h --predicate 'subsystem == "com.apple.TCC"' --style compact \
        | grep -i multishell

`AUTHREQ_ATTRIBUTION` names the `accessing` process beside `responsible`,
which is always this app.

App Management and Full Disk Access are never prompted for, only denied, so
they are added by hand in System Settings; anything a pane runs that writes
inside an app bundle needs the first, a `make install` of this app included. A
record the requirement no longer matches is ignored rather than consulted, so
a changed identity is asked about again. `tccutil reset
SystemPolicyNetworkVolumes io.multishell.app` is for a remembered no. Service
names are the log's less the `kTCCService` prefix, so App Management is
`SystemPolicyAppBundles`.

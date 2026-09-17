# One command per Bash call

Permission rules match a command prefix, such as `Bash(git diff *)`. A chained
string like `git status && git diff` is not that prefix, so an allowed command
prompts anyway. Every extra prompt is an interruption the user did not need.

Send each command as its own Bash call. Independent calls go in one response and
run in parallel, so this costs no extra round trip.

Applies to `&&`, `;`, and `||`. Do not swap `&&` for `;` to get around it; the
problem is the same and you lose the failure guard.

`cd X && cmd` is the common offender. Use an absolute path in the command
instead, or `git -C <path>`, `make -C <path>`.

## When chaining is fine

One genuine operation: a pipeline like `grep -r foo src | head -20`, a heredoc
such as `python3 - <<'PY'`, or a throwaway sequence in a scratch directory that
no permission rule covers and that would be noise as separate calls.

Never chain when part of the command mutates state and an earlier part could
fail in a way you have not handled.

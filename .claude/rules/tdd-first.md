# Failing test first

Before changing code to fix a bug, write a test that reproduces it and run it. A
test you have not seen fail proves nothing: it may assert something the code
already did, or never reach the broken path.

Read the failure. If it is not the bug you are chasing, the test is wrong, not
the code. Then fix, and re-run the file's tests to catch what the fix broke.

Never fix first and backfill a test that passes on the new code; you cannot tell
whether it would have caught the bug.

A bug behind a queue, a clock, or an HTTP call still gets a test. Find the seam
the project's existing tests already use for it, such as an injected clock, a
queue run inline or a stubbed transport, and use that. If you truly cannot
reproduce it, say why before touching the code.

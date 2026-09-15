# Audit your own diff before reporting done

The user should not have to ask "anything missing? any bugs?". Every time they
have, it found a real defect, usually one the fix introduced. Run that pass
yourself first.

Read the diff as a reviewer who did not write it and expects it to be broken.
What actually turns up here: a branch or constant dropped while moving code; a
call site of the thing you changed that you never opened; a test that passes
only in the order it was written, or asserts on a timer; an empty result
treated as an error, or an error swallowed into an empty result; an error
handler widened until it hides the case you were fixing; a read with no writer
left behind.

A suspicion is not a finding until you have run something that shows it. If you
cannot show it, call it unproven rather than fixing on a guess.

Then run the tests and linters covering what you touched, not only the test you
wrote.

Report what you checked, including "checked X, found nothing". A bare "done"
says only that you stopped.

One honest pass, not three. Do not pad the list to look thorough, and do not
keep rewriting working code because a pass found nothing.

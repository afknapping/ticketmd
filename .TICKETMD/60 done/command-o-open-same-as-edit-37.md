command o open, same as edit

Question: a literal ⌘O keypress generally isn't delivered to a raw
terminal program at all — Cmd+letter combos are normally intercepted
by the terminal app/OS before reaching stdin, unless your specific
terminal is configured to pass them through as an escape sequence
(most aren't, by default). Did you mean binding the plain letter `o`
(no modifier) as an alias for `e` (edit), or do you know your terminal
does forward ⌘O and want me to handle that specific escape sequence?

we are usually talking only INSIDE the terminal app

yes, o/open as alias for e/edit

Done: added `o` to COMMANDS as an alias for `e` everywhere - the
letter-first dispatch (o -> prompt for ticket #, opens it) and the
post-selection quick action (#N ... m=move d=delete e/o=edit) both
accept it now. Verified via pty test.



---
id: 37
ready: true
---

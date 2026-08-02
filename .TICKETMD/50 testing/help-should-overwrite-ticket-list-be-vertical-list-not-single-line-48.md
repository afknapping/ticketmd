help: should overwrite ticket list, be vertical list, not single line

Done: `h` now sets a `:help` view that replaces the board area with a
vertical "letter - name" list instead of a joined single-line message.
Any keypress dismisses it back to the normal board (handled at the
top of the main loop, before quit/dispatch, so eg. pressing `q` just
closes help rather than quitting the app). Verified via pty test.



---
id: 48
ready: true
---

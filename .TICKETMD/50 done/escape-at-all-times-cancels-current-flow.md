escape at all times cancels current flow

Cancels the in-progress sub-flow (digit entry, new/move/delete/edit
prompts, m/d/e-chooser) - does not quit the whole app from the top-level
board. Applies to the free-text prompts too (new ticket text, move
destination), which means switching those from cooked-mode `gets` to raw
per-key input so Escape can be captured there.





---
ready: true
id: 1a58c1
---

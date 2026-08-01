after lr: l at first re-renders the lr list. only on second attempt the correct one

Fixed - a refactor to generalize command-key matching (for the `s`->`snc`
fix) had dropped the special case where `l` while already showing the
released-only view should fire immediately (only sensible meaning: back
to normal) instead of waiting to disambiguate against `lr`. Verified a
single `l` press now returns to the default board right away.


---
id: 13b0fe
---

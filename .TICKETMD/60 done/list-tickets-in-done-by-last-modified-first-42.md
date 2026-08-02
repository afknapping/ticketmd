list tickets in done by last modified first

Done: `tickets_in` now sorts "done" by file mtime descending instead
of alphabetically; every other folder is unchanged. Note: since ticket
numbers are assigned in this same per-folder order, a done ticket's
number can shift if another done ticket gets touched later - expected
side effect of sorting by recency instead of a fixed order. Verified
with an isolated 3-ticket test.



---
id: 42
ready: true
---
6
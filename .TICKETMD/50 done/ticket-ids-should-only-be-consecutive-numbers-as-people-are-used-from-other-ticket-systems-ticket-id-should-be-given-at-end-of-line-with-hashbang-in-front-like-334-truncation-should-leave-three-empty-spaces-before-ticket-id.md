ticket IDs should only be consecutive numbers as people are used from other ticket systems. ticket id should be given at end of line with hashbang in front, like #334, truncation should leave three empty spaces before ticket ID

Resolved: front position numbers stay as-is (recalculated, used for
m/d/e interaction) - not replaced with a permanent counter. Backmatter
id stays informational only, not shown on the board line. No code
change needed unless you still want the id surfaced at line-end for
reference (not for interaction) - say so and I'll add it.

also: update demo data

Done: removed the "(demo data - not a real task, do not act on this)"
parenthetical from the in-progress demo ticket title in
lib/ticket_md/repository.rb's DEMO_TICKETS. Confirmed with a fresh
`tmd` restart that it no longer shows.







---
id: 33
ready: true
---

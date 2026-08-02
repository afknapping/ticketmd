question: could frontmatter also be backmatter at end of file with 10 or so empty lines before it?

My take: technically viable, and it actually simplifies the common case -
title parsing becomes "just take line 1" with no frontmatter-skip logic
needed, since almost no tickets will have any matter block at all.

But I'd drop the "10 or so empty lines" heuristic - blank-line-counting is
fragile (what's a real paragraph gap vs. the separator? off-by-one during
hand-editing breaks parsing silently). I'd instead scan from the end of
the file for the LAST line that's exactly `---`, and require a matching
`---` opening it (frontmatter's own convention, just anchored to the tail
instead of the head) - same block-delimited format, no arbitrary count.

I just implemented frontmatter-at-top for the "ready" flag ticket, so
flagging this now since switching would mean redoing that. Keep it at
top, or switch to backmatter (with an explicit delimiter, not blank-line
counting)?

→ switch to backmatter

"10 or so empty lines" is to have visual space for reading human, not as marker for what is the backmatter









---
id: 13
---

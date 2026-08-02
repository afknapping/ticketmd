list of done: no position numbers, ticket ids in front

Question: removing the position number from the done list would also
remove the only way to select a done ticket by number for m/d/e/i/o -
ticket #33 explicitly made the id "not for interaction," position
number only. Is that intentional (done entries become display-only,
not actionable via number), or should the id itself become the
interactive selector for done entries specifically (type the id to
act on that ticket, instead of a position number)?

it is ok, for now: no command interaction needed for done tickets

Done: done entries now lead with `#id` instead of a position number
(Printer.board), and visible_ticket_numbers excludes "done" entirely
from the digit-selectable pool, even in the `ld` expanded view.
Verified: done-only board renders id-first with no number, and typing
a digit in `ld` resolves to a real (non-done) ticket rather than a
done one.


---
id: 43
ready: true
---

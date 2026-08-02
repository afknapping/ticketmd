inline setup

if ticket md was started and there is no structure in the project yet, make default structure

Done: `tmd` (interactive) now calls `repo.setup!` on startup, which is
already idempotent (no-op once folders exist) - so it just scaffolds
the default structure the first time, no separate `tmd setup` step
needed. The "No ticket folders found" message/branch is gone since
it's now unreachable. Scoped to interactive mode only - `tmd list`
still asks you to run `tmd setup` first, since silently creating
folders from a one-shot reporting command felt like an unwanted side
effect. Verified on a completely fresh directory with no .TICKETMD at
all.


---
id: 47
ready: true
---

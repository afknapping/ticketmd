bridge from specific mac os reminder list to backlog (even possible from terminal?)

Possible via AppleScript/`osascript` talking to Reminders.app (no public
CLI otherwise) - will trigger a one-time macOS Automation permission
prompt for whatever runs `tmd`.

command: snc -> "sync to reminder list" -> show a numbered list of
available reminder lists, with extra option n = new list -> expect a name
-> create that list

One-way: pull reminders from the chosen list into backlog, deleting each
reminder from Reminders once it's been transferred into a ticket.

Implemented (`snc` command in lib/ticket_md/reminders.rb +
interactive.rb). AppleScript syntax verified via `osacompile` and the
Ruby-side flow verified with a stubbed Reminders module (list picker, new
list, import, delete-after-import) - none of that touches your real
Reminders data. The actual live AppleScript-talking-to-Reminders.app path
is NOT yet verified against real data, and will trigger a one-time
Automation permission prompt the first time you run `snc` for real -
please test that part yourself.











---
ready: true
id: 23
---

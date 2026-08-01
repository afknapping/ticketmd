# Ticket, MD

A plain-markdown ticket system for the terminal. A ticket is a file.
Order is absolute, encoded by which folder it's in. The filesystem is
the database — no server, no external dependencies beyond Ruby's
standard library.

CLI Output             |  Files and Folders
:-------------------------:|:-------------------------:
![](https://github.com/user-attachments/assets/62947371-debc-4547-a96d-bd24cbaca5c5) |  ![](https://github.com/user-attachments/assets/c308c5f0-07bc-4d84-906e-40361472d70e)

Runs in any terminal, including a Claude Code terminal pane.

## Philosophy

- No database, no server-side source of truth — the `.md` files are the data.
- One ticket = one file. Editable in any text editor, greppable,
  diffable, git-friendly.
- Status is a folder, not a field: `backlog` → `next` → `in progress` →
  `testing` → `done`. Moving a ticket between folders *is* a status
  change, whether done through the app or by hand in Finder.

## Install

```bash
gem build ticket_md.gemspec
gem install ./ticket_md-*.gem
```

This puts `tmd` on your `PATH`.

## Usage

```bash
tmd setup   # scaffold the folder structure + a couple of example tickets
tmd         # interactive view
tmd list    # one-shot, non-interactive listing
```

Ticket data lives in a hidden `.TICKETMD/` folder wherever you run `tmd`
from — each project gets its own independent ticket set.

### Interactive commands

| Key | Action |
|---|---|
| `n` | new ticket |
| `e` | edit (opens in the system default app for `.md`) |
| `m` | move to another stage |
| `d` | delete (soft — moves to Trash) |
| `l` | refresh |
| `ld` | show the full `done` list (collapsed to a count by default) |
| `snc` | sync from a macOS Reminders list |
| a number | select a ticket, then act on it |
| `q` | quit |

Ticket numbers are always typeable as soon as they're unambiguous — no
need to press Enter unless there's a genuine ambiguity to resolve.

## Ticket format

A ticket is a plain markdown file. The first line is the title.
Optional metadata lives as YAML "backmatter" at the end of the file:

```markdown
fix the login redirect loop

Some more detail about the bug, if useful.


---
id: 8f3a2c
ready: true
---
```

- `id` is assigned automatically and never changes, even if the file
  gets renamed.
- `ready: true` shows a green checkmark — a signal that a ticket is
  clear enough to build.
- `question: true` shows a yellow warning triangle — a signal that a
  ticket still has an open question attached to it.

## License

Not yet decided.

# Ticket, MD

A plain-markdown ticket system for the terminal. A ticket is a file.
Order is absolute, encoded by which folder it's in. The filesystem is
the database: no server, no dependencies beyond Ruby.


Runs in any terminal, including a Claude Code terminal pane.

<table>
<tr>
<th>CLI Output</th>
<th>Files and Folders</th>
</tr>
<tr>
<td>

```
 TICKET, MD 

NEW
  01 explore dark mode support                  #12

REFINE
  02 add pagination to search                    #8

READY
  03 write onboarding docs                        #5

IN PROGRESS
  04 refactor auth middleware                     #3

TESTING
  05 verify csv export                            #9

DONE (2)
```

</td>
<td>

```
.TICKETMD/
├── 10 new/
│   └── explore-dark-mode-support-12.md
├── 20 refine/
│   └── add-pagination-to-search-8.md
├── 30 ready/
│   └── write-onboarding-docs-5.md
├── 40 in progress/
│   └── refactor-auth-middleware-3.md
├── 50 testing/
│   └── verify-csv-export-9.md
└── 60 done/
    ├── fix-off-by-one-error-in-date-picker-1.md
    └── upgrade-postgres-client-2.md
```

</td>
</tr>
</table>

## Philosophy

- No database, no server-side source of truth — the `.md` files are the data.
- One ticket = one file. Editable in any text editor, greppable,
  diffable, git-friendly.
- Status is a folder, not a field: `new` → `refine` → `ready` →
  `in progress` → `testing` → `done`. Moving a ticket between folders
  *is* a status change, whether done through the app or by hand in
  Finder.
- `new` is for drafting — leave tickets you're actively writing there,
  untouched. `refine` is for review — mark a reviewed ticket
  `ready: true` or `question: true` (see below). `ready` is the signal
  to actually start on it.

## Working with an AI agent

Ticket, MD was built for pairing with an AI coding agent (Claude Code
or similar) that works out of the same repo. From your side, the loop
looks like this:

1. `n` → **Drop a ticket in `new`.** Write it in your own words, one line or a whole paragraph — whatever's fastest. This is your scratch space; the agent won't touch anything sitting here.
2. `o` → **Open ticket** in your default markdown editor and add more specs or questions.
2. `m` → **Move it to `refine` when it's ready for a second pair of eyes.**
   The agent reviews it and either marks it `ready` (clear enough to
   build) or `question` (leaves an actual question in the ticket body
   for you to answer).
3. `o` → **Open and answer any questions, then `m` → move it to `ready`.** That's the
   signal to start work — the agent picks it up, implements it,
   verifies it actually works, and leaves a note in the ticket
   describing what it did.
4. **Review what landed in `testing`,** and `m` → move it to `done` once
   you're happy. The agent never promotes its own work past
   `testing` — that check is always yours.

This repo ships a Claude Code skill at
[`.claude/skills/ticket-md/SKILL.md`](.claude/skills/ticket-md/SKILL.md)
that teaches an agent this entire workflow — the ticket/backmatter
format, the pipeline stages, and how to watch `refine`/`ready` for
changes — so it picks the loop up automatically in any project using
`tmd`, without you having to explain it each time.

## Install

```bash
gem build ticket_md.gemspec
gem install ./ticket_md-*.gem
```

This puts `tmd` on your `PATH`.

## Usage

```bash
tmd         # interactive view - scaffolds the folder structure + a
            # couple of example tickets automatically on first run
tmd setup   # scaffold explicitly, without entering the interactive view
tmd list    # one-shot, non-interactive listing
```

Ticket data lives in a hidden `.TICKETMD/` folder wherever you run `tmd`
from — each project gets its own independent ticket set.

### Interactive commands

| Key | Action |
|---|---|
| `n` | new ticket |
| `e` / `o` | edit / open (opens in the system default app for `.md`) |
| `m` | move to another stage |
| `d` | delete (soft — moves to Trash) |
| `i` | commit + push just this ticket, then open it on GitHub for a quick image paste |
| `l` | `git pull`, then refresh |
| `ld` | show the full `done` list (collapsed to a count by default) |
| `snc` | sync from a macOS Reminders list |
| a number | select a ticket, then act on it |
| `q` | quit |

Ticket numbers are always typeable as soon as they're unambiguous — no
need to press Enter unless there's a genuine ambiguity to resolve.

Each line also ends with the ticket's permanent id (eg. `#42`) — the
position number on the left is just for quick selection and can shift
as tickets move; the id at the right never changes. `done` is the
exception: those entries lead with `#id` instead of a position number
and aren't number-selectable, and are listed most-recently-touched
first rather than alphabetically.

## Ticket format

A ticket is a plain markdown file. The first line is the title.
Optional metadata lives as YAML "backmatter" at the end of the file:

```markdown
fix the login redirect loop

Some more detail about the bug, if useful.


---
id: 42
ready: true
---
```

- `id` is a plain consecutive number, assigned automatically and never
  changes, even if the file gets renamed — it's also appended to the
  filename itself (eg. `fix-the-login-redirect-loop-42.md`), so it's
  visible straight from `ls` or `git status` without opening the file.
- `ready: true` shows a green checkmark — a signal that a ticket is
  clear enough to build.
- `question: true` shows a yellow warning triangle — a signal that a
  ticket still has an open question attached to it.

## License

Not yet decided.

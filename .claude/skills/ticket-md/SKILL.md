---
name: ticket-md
description: Work with the `tmd` (Ticket, MD) plain-markdown ticket system - a project's tickets live as .md files under a `.TICKETMD/` folder, organized into stage folders (new/refine/ready/in progress/testing/done). Use this skill whenever a `.TICKETMD/` folder is present in the project, or the user mentions tmd, ticket_md, or "tickets" as their task-tracking system - even if they don't explicitly ask to "use the ticket-md skill." Covers detecting/setting up the tool, the ticket file format, watching for ticket changes, and the review-and-implement workflow tied to the refine/ready folders.
---

# Ticket, MD

A ticket is a plain markdown file; its folder is its status. No database,
no server - the filesystem is the source of truth.

## Detecting and setting up

If `.TICKETMD/` already exists in the project root, the tool is set up -
skip to "Ticket format" below.

If it doesn't exist yet but the project has a `tmd` binary available (check
`which tmd` or a local `bin/tmd`), just run it - interactive mode
auto-scaffolds the default folder structure on first run, no separate setup
step needed.

If `tmd` isn't installed at all, and the ticket_md gem source is available
(a repo with `ticket_md.gemspec`), install it from there:

```bash
gem build ticket_md.gemspec
gem install ./ticket_md-*.gem
```

This puts `tmd` on the `PATH`. Running `tmd` (no args) then creates the
folder structure automatically.

## Ticket format

A ticket is a plain markdown file. The first line is the title. Optional
metadata lives as YAML "backmatter" - a `---`/`---` block at the END of the
file, not the top:

```markdown
fix the login redirect loop

Some more detail about the bug, if useful.


---
id: 42
ready: true
---
```

- `id` - a plain sequential number, assigned automatically the first time
  the file is touched, and permanent from then on (survives renames).
- `ready: true` - green checkmark. Signals the ticket is clear enough to
  build.
- `question: true` - yellow warning triangle. Signals there's an open
  question blocking work on it.

## The pipeline

`new` → `refine` → `ready` → `in progress` → `testing` → `done`

- **`new`**: the user is actively drafting here. Never touch, read closely,
  or act on a ticket sitting in `new` - editing it while they're mid-thought
  causes real conflicts. Leave it alone until they move it themselves.
- **`refine`**: tickets ready for review. As soon as you notice one here
  (no need to wait), read it and decide:
  - If the request is clear and actionable: mark `ready: true` in the
    backmatter AND move the file into the `ready` folder, in the same step.
  - If something's genuinely unclear: mark `question: true`, and write the
    actual question into the ticket body (not just the flag) - be specific
    about what's ambiguous and why it matters for the implementation.
  Never leave a reviewed ticket unmarked in `refine`.
- **`ready`**: a ticket landing here - whether the user dragged it there or
  you just moved it during review - is itself the "start working" signal.
  No further confirmation needed. Move it to `in progress`, implement it,
  verify the change actually works (run it, test it - don't just assume),
  write a short note directly in the ticket body describing what was done
  and how it was verified, then move the file to `testing`.
- **`testing`**: sits here for the user's own review. Only the user
  promotes a ticket from `testing` to `done` - never do this yourself.

The one hard rule across all of this: never implement something sitting in
`new` or `refine` without it having gone through the ready-and-moved step
first. A ticket only becomes actionable once it's in `ready` (or beyond).

## Watching for changes

Since ticket files change outside the conversation (the user edits them
directly, or moves them between folders in Finder/an editor), set up a
background watcher on the project's `refine` and `ready` folders so you get
notified rather than having to be told or poll manually. Use the `Monitor`
tool (not a plain background shell command - only `Monitor` actually
notifies on each new line) with a command like this, once per folder:

```bash
DIR="<project>/.TICKETMD/20 refine"
prev=""
while true; do
  cur=$(find "$DIR" -maxdepth 1 -name "*.md" -exec stat -f "%N %m" {} \; 2>/dev/null | sort)
  if [ -n "$cur" ] && [ "$cur" != "$prev" ]; then
    echo "refine folder changed:"
    echo "$cur"
  fi
  prev="$cur"
  sleep 2
done
```

Swap `20 refine` for `30 ready` (and the echoed label) for the second
watcher. The exact numeric prefixes can vary if a project customized its
folder order - match whatever `refine`/`ready` folders actually exist under
`.TICKETMD/`. Set these up early, as soon as you're working in a
ticket_md-using project - not just when asked.

When a Monitor notification fires, treat it the same as noticing the change
yourself: review anything new in `refine`, and pick up anything that landed
in `ready`.

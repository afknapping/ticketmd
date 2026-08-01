initial git commit, push, README, github pages enable so visible at afknapping.de/ticketmd

Resolved plan:
1) restructure first: all ticket folders (backlog/next/in progress/
   testing/released) move under a hidden `.TICKETMD/` subfolder, both as
   the new default (Repository/setup!) and physically in this project.
   App-managed files (.reminders-list config, .TRASH fallback) move
   under there too, keeping the project root clean.
2) create a new public GitHub repo (name: "ticketmd", matching the
   target URL path) - none exists yet.
3) push everything, including all real tickets (not gitignored).
4) add a README; GitHub Pages just renders it via the default Jekyll
   theme, no custom index.html needed.
5) enable GitHub Pages (via `gh api`, no native `gh` subcommand for it),
   pointed at afknapping.de - DNS record already exists on their end, no
   setup needed there.

Still pausing for explicit confirmation before the actual push/Pages-
enable step once this is picked up, per the earlier note - a lot of this
is public/external and not something to run off a ticket alone.

.gitignore: yes, .claude/ - it only holds settings.local.json (explicitly
"local", per-machine) and scheduled_tasks.lock (a runtime lock file),
neither belongs in version control. Also .DS_Store.

Done so far (all local, nothing public yet): .gitignore, README.md,
`git init`, and the initial commit (47 files - code + all real tickets,
as agreed). Note: md-tickets-spec.md is missing from the project root -
I didn't touch it, not sure if you deleted it or it's just misplaced,
flagging in case it's not intentional.

Stopping here for explicit confirmation before: creating the actual
public GitHub repo, pushing, and enabling Pages with the custom domain -
say go and I'll do it.

---
id: 2fcbe5
ready: true
---

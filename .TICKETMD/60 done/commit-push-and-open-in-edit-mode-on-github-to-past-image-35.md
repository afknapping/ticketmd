commit, push and open in edit mode on github to past image

Question: is this a personal workflow reminder for you (no code
needed - just a habit of opening GitHub's web editor to paste/drag
images, which auto-uploads them and gives you a URL), or do you want
an actual `tmd` feature - eg. a command that commits, pushes, and
opens the repo's edit view for a given file in your browser?

it’s a feature to get an image into a markdown file fast without having to handle files manually and/or locally.

the command is i image

commit, push, open in edit mode is automatic, so what i see is an editing window on github and there i can just do cmd-v to paste my pixel clipboard.

l list should also do git pull, so i get updated tickets

Follow-up question: two things still need pinning down before I build
the `i`/image command:
1. Which file does it open in GitHub's edit view - always README.md,
   or should it prompt for a filename / default to the current
   ticket's file somehow?
2. "commit, push... is automatic" - does that mean committing
   whatever's currently modified in the repo (which could sweep up
   unrelated in-progress work), or should it only push what's already
   committed and just open the edit view for the paste step?
Also: "l should also git pull" reads like a separate, unrelated ask
bundled into this ticket - want that split into its own ticket, or
folded into this same one?

this is all about a ticket. you should only commit that ticket file, then push to gh, then open that ticket file in edit mode

Done: added `i` (image) - prompts for a ticket #, then `git add` +
`git commit` (just that one file, skipped gracefully if nothing
changed) + `git push`, then opens that ticket's GitHub "edit this
file" URL in the browser via `open`. Also added `l`/list doing `git
pull` before refreshing (pull failures show a message but don't block
the refresh). New lib/ticket_md/github.rb module. Verified both via
pty tests against a local fake git remote (not the real GitHub) -
commit landed correctly, the URL is percent-encoded for the folder
names with spaces (eg. "10 new" -> "10%20new"), "nothing to commit" is
handled without erroring, and `l` correctly pulls in an external
change pushed from elsewhere.


---
id: 35
ready: true
---

fix renaming loop: leaves old file in editor then dublicattes file after save

Root cause: tickets currently have no identity beyond their filename (no
`id:` field - dropped for v1 minimalism). Sequence: edit content in an
external editor -> save -> reconcile renames the file to match the new
title -> the editor still holds the OLD path -> next save from the editor
recreates the old filename from its stale buffer -> reconcile now sees two
files, treats both as real tickets -> duplicate.

Two ways to fix, different amounts of work:
1) Add a lightweight persistent id back (even without full YAML
   frontmatter) so a resurrected old filename can be recognized as "same
   ticket, stale copy" instead of a new one.
2) No id: when reconcile finds two tickets with identical (or
   near-identical) content, treat the newer file as a stale re-save of the
   older one and soft-delete (trash) the duplicate instead of keeping both.

Which direction do you want - add an id, or duplicate-content merge?

add an id





---
ready: true
id: 23fe4f
---

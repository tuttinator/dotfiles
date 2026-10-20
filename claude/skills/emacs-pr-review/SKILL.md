---
name: emacs-pr-review
description: Use when reviewing a GitHub pull request alongside the user's Emacs pr-review buffer, especially PRs in a stack, or when asked to open or refresh a PR in Emacs.
---

# Emacs PR review

The user reads PRs in Doom Emacs with `pr-review`; you read them with `gh` and
`git`. Keep the two in step, review against the real base, and post only the
comments the user picks.

Scripts live in `~/.claude/skills/emacs-pr-review/scripts/`.

## 1. Open the PR in Emacs

```bash
~/.claude/skills/emacs-pr-review/scripts/open-pr.sh <number|url>
```

It returns at once and prints the buffer name (`*pr-review owner/repo/N*`).
`pr-review` fetches synchronously, so never call it directly through
`emacsclient -e`: Emacs freezes until the fetch ends, and a large diff can take
a while. An existing buffer is refreshed in place, which matters after a
force-push. Confirm the buffer appeared:

```bash
emacsclient -e '(mapcar (function buffer-name) (seq-filter (lambda (b) (string-match-p "/<N>\\*" (buffer-name b))) (buffer-list)))'
```

Don't use the user's `prr` shell function: it opens a terminal frame and blocks.

## 2. Read the PR and its place in a stack

- `gh pr view N`, `gh pr view N --json baseRefName,headRefOid,commits`.
- A base other than the default branch means a stack. List the PRs above and
  below it so findings can be tracked across them.
- Save the diff to the scratchpad and strip generated noise before reading:

  ```bash
  gh pr diff N > pr.diff
  awk '/^diff --git/{p = ($0 !~ /meta\/[0-9]+_snapshot\.json|\.snap$|lock\.(json|yaml)$/)} p' pr.diff > pr-clean.diff
  ```

## 3. Check against the real base

GitHub reports stacked PRs as clean against their own base, which hides
conflicts with the default branch.

```bash
git fetch -q origin && git fetch -q origin pull/N/head:rv-N
git merge-tree --write-tree --name-only origin/<default> rv-N | grep -i conflict
```

For migration frameworks with a journal (Drizzle `meta/_journal.json` and so
on), compare migration numbers and timestamps with the default branch.

## 4. Review

- Use the repository's own review skill when it has one (for example
  `/athena-code-review` in Athena); otherwise `/code-review`.
- For a diff over about 5,000 lines, split it into slices (writers and
  locking, reads and auth, UI and tests) and review them in parallel with
  forks. Spot-check their headline claims before reporting.
- Read surrounding code at the PR head with `git show "rv-N:path"`.

## 5. Track findings across the stack

For each finding, check whether a later PR fixes it: fetch each later head and
compare the relevant lines or `git diff --stat rv-N rv-top -- <files>`.

- In zsh, write `"${ref}:path"`, never `"$ref:path"`. zsh reads `:t`, `:h`
  and similar as history modifiers and mangles the revision.
- Before reporting stale results, check whether the branch moved:
  `git log -1 --format='%h %cd' rv-N`. Authors often force-push the whole stack
  after review comments, which can fix earlier findings.

## 6. Draft, then post only what the user picks

- Show drafts first, numbered, each with its path and line.
- Post only the comments the user names. Respect "not the nit".
- Re-read the head SHA right before posting, and check every target line:

  ```bash
  gh pr diff N > pr.diff
  ~/.claude/skills/emacs-pr-review/scripts/check-lines.py pr.diff path/a.ts:174 path/b.tsx:42
  ```

- Post one review with `event: "COMMENT"` through
  `gh api -X POST repos/OWNER/REPO/pulls/N/reviews --input review.json`.
  Build the JSON with a script rather than shell quoting. Never use `APPROVE`
  or `REQUEST_CHANGES` unless asked. A general comment goes in the review
  `body`; a single extra inline goes through `pulls/N/comments`.
- No attribution trailers or signatures in comment text.

## 7. Clean up

Delete every temporary ref and worktree you created
(`git branch -D rv-N …`, `git worktree remove --force …`), and tell the user
the buffer name for the next PR.

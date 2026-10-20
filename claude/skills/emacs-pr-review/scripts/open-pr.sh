#!/usr/bin/env bash
# Open (or refresh) a GitHub PR in the running Emacs's pr-review buffer without
# blocking: pr-review fetches synchronously, so the call is queued on a zero-delay
# timer and emacsclient returns at once. Unlike the interactive `prr` shell
# function, this never opens a terminal frame.
#
#   open-pr.sh            PR for the current branch
#   open-pr.sh 129        PR 129 of the current repo
#   open-pr.sh <url>      any PR URL
#
# Prints the buffer name to watch for, e.g. *pr-review owner/repo/129*.
set -euo pipefail

arg=${1:-}
if [[ -z $arg || $arg =~ ^[0-9]+$ ]]; then
  url=$(gh pr view ${arg:+"$arg"} --json url --jq .url)
else
  url=$arg
fi

if [[ ! $url =~ ^https://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)$ ]]; then
  echo "Not a GitHub PR URL: $url" >&2
  exit 2
fi
buffer="*pr-review ${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[3]}*"

if ! emacsclient -e t >/dev/null 2>&1; then
  echo "No Emacs server is running; start Emacs (Doom starts the server) and retry." >&2
  exit 3
fi

# An existing buffer is refreshed in place so a force-pushed PR shows its new head.
emacsclient -e "(run-at-time 0 nil (lambda ()
  (let ((buffer (get-buffer \"$buffer\")))
    (if buffer
        (with-current-buffer buffer (pr-review-refresh))
      (pr-review \"$url\")))))" >/dev/null

echo "$buffer"

#!/usr/bin/env python3
"""Check that inline-comment targets fall inside a PR's diff hunks.

GitHub rejects a whole review when any comment's line is outside the diff, so
run this before posting.

    gh pr diff 129 > pr.diff
    check-lines.py pr.diff src/a.ts:174 src/b.tsx:42

Exits non-zero when any target is not commentable on the RIGHT side.
"""
import re
import sys


def hunk_ranges(diff_path: str) -> dict[str, list[tuple[int, int]]]:
    ranges: dict[str, list[tuple[int, int]]] = {}
    current = None
    with open(diff_path, encoding="utf-8") as diff:
        for line in diff:
            if line.startswith("+++ "):
                current = line[6:].strip() if line.startswith("+++ b/") else None
                continue
            match = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
            if match and current:
                start = int(match.group(1))
                count = int(match.group(2) or 1)
                ranges.setdefault(current, []).append((start, start + count - 1))
    return ranges


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    ranges = hunk_ranges(sys.argv[1])
    failed = False
    for target in sys.argv[2:]:
        path, _, line = target.rpartition(":")
        number = int(line)
        ok = any(start <= number <= end for start, end in ranges.get(path, []))
        failed |= not ok
        print(f"{'ok      ' if ok else 'NOT IN DIFF'} {path}:{number}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

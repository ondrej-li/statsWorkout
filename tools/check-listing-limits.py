#!/usr/bin/env python3
"""Checks every App Store text in docs/app-store-listing.md against Apple's limits.

App Store Connect only tells you a field is too long when you paste it in, so the
counts are verified here instead. Run it after editing the listing:

    python3 tools/check-listing-limits.py

Exits 1 when a field is over its limit or a required field is missing.
"""

import pathlib
import re
import sys

LIMITS = {
    "promotional text": 170,
    "description": 4000,
    "keywords": 100,
    "what's new": 4000,
    "review notes": 4000,
    "subtitle": 30,
    "name": 30,
}

# At least one English and one Czech block of each shipping field.
REQUIRED = [
    "Promotional text — English",
    "Description — English",
    "Description — Czech",
    "Keywords — English",
    "Keywords — Czech",
    "What's new — 1.1.0",
    "Review notes",
]

LISTING = pathlib.Path(__file__).resolve().parent.parent / "docs" / "app-store-listing.md"


def limit_for(heading: str) -> int | None:
    label = heading.split("—")[0].split("(")[0].strip().lower()
    return LIMITS.get(label)


def main() -> int:
    text = LISTING.read_text()
    blocks: list[tuple[str, str]] = []
    heading = ""
    collecting: list[str] | None = None
    for line in text.splitlines():
        if line.startswith("## "):
            heading = line[3:].strip()
            collecting = None
        elif line.strip() == "```":
            if collecting is None:
                collecting = []
            else:
                blocks.append((heading, "\n".join(collecting)))
                collecting = None
        elif collecting is not None:
            collecting.append(line)

    headings = re.findall(r"^## (.+)$", text, re.M)
    if not blocks:
        print("no ```-fenced copy found")
        return 1

    failures = 0
    for heading, block in blocks:
        limit = limit_for(heading)
        if limit is None:
            continue
        length = len(block)
        state = "ok" if length <= limit else "TOO LONG"
        if length > limit:
            failures += 1
        print(f"{length:>5} / {limit:<5} {state:<9} {heading}")

    for required in REQUIRED:
        if not any(heading.startswith(required) for heading, _ in blocks):
            print(f"missing required block: {required}")
            failures += 1

    for heading in headings:
        if limit_for(heading) is None and heading not in ("App information", "URLs", "App Privacy answers",
                                                          "Screenshots", "Export compliance",
                                                          "Localised metadata beyond English and Czech"):
            print(f"unrecognised section: {heading}")
            failures += 1

    print("all limits satisfied" if failures == 0 else f"{failures} problem(s)")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

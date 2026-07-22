"""Shared snippet-extraction logic for slide-code and key-audit.

A master .R script marks each slide excerpt with a named fence:

    ## ---- slide: fit-model ----
    fit <- optim(...)
    ...

A snippet runs from the line after its fence to the next fence line (any
line starting with `## ----`) or the end of the file. Fence lines are never
part of the snippet. Blank lines at the edges are trimmed.

A snippet SPEC (used by `slide-code script.R SPEC` and
`key-audit --code script.R SPEC`) is one of:
    all            the whole file
    12:24          a 1-indexed inclusive line range
    fit-model      a fence name
"""

import re

FENCE_RE = re.compile(r"^\s*##\s*----\s*slide:\s*(?P<name>[A-Za-z0-9_-]+)\s*----\s*$")
ANY_FENCE_RE = re.compile(r"^\s*##\s*----")
RANGE_RE = re.compile(r"^(\d+):(\d+)$")


def snippet_names(code):
    """All fence names in the file, in order."""
    return [m.group("name") for line in code.splitlines()
            if (m := FENCE_RE.match(line))]


def _trim(lines):
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def extract(code, spec):
    """Return (snippet_text, label) for a SPEC applied to the file's code.

    Raises ValueError for an unknown fence name or malformed spec.
    """
    lines = code.splitlines()
    if spec is None or spec == "all":
        return "\n".join(_trim(lines[:])), "all"

    m = RANGE_RE.match(spec)
    if m:
        first, last = int(m.group(1)), int(m.group(2))
        if not 1 <= first <= last:
            raise ValueError(f"bad line range: {spec}")
        return "\n".join(_trim(lines[first - 1 : last])), f"{first}:{last}"

    for i, line in enumerate(lines):
        fm = FENCE_RE.match(line)
        if fm and fm.group("name") == spec:
            body = []
            for l in lines[i + 1 :]:
                if ANY_FENCE_RE.match(l):
                    break
                body.append(l)
            return "\n".join(_trim(body)), spec
    known = ", ".join(snippet_names(code)) or "(none)"
    raise ValueError(f"no fence '## ---- slide: {spec} ----' — snippets in file: {known}")

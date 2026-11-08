# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MPL_MARKERS = (
    "This Source Code Form is subject to the terms of the Mozilla Public",
    "mozilla.org/MPL/2.0/",
)
HEADER_EXTENSIONS = {
    ".c",
    ".cc",
    ".cjs",
    ".cpp",
    ".css",
    ".h",
    ".hpp",
    ".html",
    ".js",
    ".mjs",
    ".ps1",
    ".py",
    ".rs",
    ".sh",
    ".toml",
    ".ts",
    ".tsx",
    ".xhtml",
    ".xml",
    ".yaml",
    ".yml",
}


@dataclass(frozen=True)
class LicenseIssue:
    path: Path
    reason: str


def git(repo, *arguments, check=True):
    return subprocess.run(
        ["git", *arguments],
        cwd=repo,
        check=check,
        capture_output=True,
        text=True,
    )


def has_mpl_header(content):
    prefix = content[:2048]
    return all(marker in prefix for marker in MPL_MARKERS)


def resolve_base(repo, base):
    """Use the pinned upstream ref when available, otherwise the in-tree HEAD."""
    result = git(repo, "rev-parse", "--verify", base, check=False)
    return base if result.returncode == 0 else "HEAD"


def git_root(repo):
    return Path(git(repo, "rev-parse", "--show-toplevel").stdout.strip()).resolve()


def scoped_path(repo, git_path):
    """Convert a main-repository path to one relative to this nested app."""
    repo = Path(repo).resolve()
    root = git_root(repo)
    prefix = repo.relative_to(root)
    candidate = Path(git_path)
    if prefix != Path("."):
        if candidate.parts[: len(prefix.parts)] != prefix.parts:
            return None
        candidate = candidate.relative_to(prefix)
    return candidate.as_posix()


def changed_paths(repo, base):
    statuses = {}
    committed = git(repo, "diff", "--name-status", "--find-renames", f"{base}...HEAD")
    working = git(repo, "diff", "--name-status", "--find-renames", "HEAD")
    for output in (committed.stdout, working.stdout):
        for line in output.splitlines():
            fields = line.split("\t")
            status = fields[0][0]
            path = scoped_path(repo, fields[-1])
            if path is None:
                continue
            if status != "D":
                statuses[path] = status
    untracked = git(repo, "ls-files", "--others", "--exclude-standard")
    for git_path in untracked.stdout.splitlines():
        path = scoped_path(repo, git_path)
        if path is not None:
            statuses[path] = "A"
    return statuses


def base_content(repo, base, path):
    repo = Path(repo)
    root = git_root(repo)
    prefix = repo.resolve().relative_to(root)
    git_path = Path(path)
    if prefix != Path("."):
        git_path = prefix / git_path
    result = git(repo, "show", f"{base}:{git_path.as_posix()}", check=False)
    return result.stdout if result.returncode == 0 else None


def validate_repository(repo=ROOT, base="upstream/stable"):
    repo = Path(repo)
    base = resolve_base(repo, base)
    issues = []
    for relative, status in sorted(changed_paths(repo, base).items()):
        path = Path(relative)
        if path.suffix.lower() not in HEADER_EXTENSIONS:
            continue
        absolute = repo / path
        try:
            current = absolute.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        previous = base_content(repo, base, relative)
        requires_header = status == "A" or (
            previous is not None and has_mpl_header(previous)
        )
        if requires_header and not has_mpl_header(current):
            issues.append(
                LicenseIssue(
                    path,
                    "falta el encabezado MPL-2.0 o se eliminó el existente",
                )
            )
    return issues


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Valida licencias en cambios propios sin reescribir deuda upstream."
    )
    parser.add_argument("--repo", type=Path, default=ROOT)
    parser.add_argument("--base", default="upstream/stable")
    arguments = parser.parse_args(argv)

    issues = validate_repository(arguments.repo, arguments.base)
    if not issues:
        print("Licencias de cambios DylanOS: OK")
        return 0
    for issue in issues:
        print(f"ERROR: {issue.path}: {issue.reason}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Create one isolated synthetic test identity; print its path, never its value."""
import argparse
import json
import os
from pathlib import Path
import secrets
import stat

FILENAME = "session_identity.private.json"
KIND = "isolated_test_session_identity_v1"


def create(directory: Path, project: Path) -> Path:
    if os.name != "posix":
        raise ValueError("Private test identity setup currently requires POSIX permissions.")
    directory = directory.expanduser().absolute()
    project = project.resolve(strict=True)
    if directory.exists() or directory.is_symlink():
        raise ValueError("Use a new test-session directory; existing identities are never replaced.")
    parent = directory.parent
    if not parent.is_dir() or parent.resolve(strict=True) != parent:
        raise ValueError("The existing parent directory must be canonical and free of symlinks.")
    if directory == project or project in directory.parents:
        raise ValueError("The test-session directory must be outside the project tree.")
    directory.mkdir(mode=0o700)
    if stat.S_IMODE(directory.stat().st_mode) != 0o700:
        directory.rmdir()
        raise ValueError("Cannot establish private test-session directory permissions.")
    path = directory / FILENAME
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    created_file = False
    try:
        fd = os.open(path, flags, 0o600)
        created_file = True
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            if stat.S_IMODE(os.fstat(stream.fileno()).st_mode) != 0o600:
                raise ValueError("Cannot establish private identity file permissions.")
            payload = {"kind": KIND, "session_id": secrets.token_hex(16),
                       "resume_secret": "resume_" + secrets.token_hex(16)}
            json.dump(payload, stream, separators=(",", ":"))
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        if created_file and path.is_file() and not path.is_symlink():
            path.unlink()
        if not any(directory.iterdir()):
            directory.rmdir()
        raise
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    args = parser.parse_args()
    try:
        path = create(args.directory, args.project)
    except (OSError, ValueError):
        parser.exit(2, "Test identity preparation failed; check the new external directory and permissions.\n")
    print(path)


if __name__ == "__main__":
    main()

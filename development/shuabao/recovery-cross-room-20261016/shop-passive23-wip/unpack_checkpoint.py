#!/usr/bin/env python3
"""Validate actual archive parts and safely unpack regular files into a new directory."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def no_links(path):
    require(not path.is_symlink() and not any(p.is_symlink() for p in path.parents), "Symlink path: " + str(path))
    return path


def main():
    ap = argparse.ArgumentParser()
    for name in ("parts-dir", "output", "manifest-sha256"):
        ap.add_argument("--" + name, required=True)
    a = ap.parse_args()
    root = no_links(Path(a.parts_dir).absolute())
    out = no_links(Path(a.output).absolute())
    require(root.is_dir() and not out.exists() and out.parent.is_dir(), "Input must exist; output must be new with an existing parent")
    require(root != out and root not in out.parents and out not in root.parents, "Output must be separate from parts")
    raw = no_links(root / "ARCHIVE_PARTS.json").read_bytes()
    require(digest(raw) == a.manifest_sha256, "Archive parts manifest SHA mismatch")
    manifest = json.loads(raw)
    chunks = []
    seen = set()
    require(0 < len(manifest["parts"]) < 1000, "Invalid part count")
    for index, record in enumerate(manifest["parts"]):
        name = record["file"]
        require(name == "archive.part%03d" % index and name not in seen, "Invalid part name/order")
        seen.add(name)
        p = no_links(root / name)
        require(p.is_file() and p.stat().st_size == record["bytes"] and record["bytes"] <= 65536, "Part size mismatch")
        data = p.read_bytes()
        require(digest(data) == record["sha256"], "Part SHA mismatch")
        chunks.append(data)
    archive = b"".join(chunks)
    require(len(archive) == manifest["bytes"] and digest(archive) == manifest["sha256"], "Whole archive mismatch")
    files = {}
    total = 0
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        for member in tar:
            name = member.name
            path = PurePosixPath(name)
            require(member.isfile() and name and not path.is_absolute() and ".." not in path.parts and str(path) == name and "\\" not in name and name not in files, "Unsafe or duplicate tar member")
            total += member.size
            require(member.size >= 0 and total <= 32 * 1024 * 1024, "Unexpected unpacked size")
            files[name] = tar.extractfile(member).read()
            require(len(files[name]) == member.size, "Truncated tar member")
    require("PACKAGE_FILES.json" in files and digest(files["PACKAGE_FILES.json"]) == manifest["package_manifest_sha256"], "Embedded manifest mismatch")
    package = json.loads(files["PACKAGE_FILES.json"])
    require(set(files) == set(package) | {"PACKAGE_FILES.json"}, "Package inventory mismatch")
    for name, record in package.items():
        require(len(files[name]) == record["bytes"] and digest(files[name]) == record["sha256"], "Embedded file mismatch: " + name)
    out.mkdir()
    for name, data in files.items():
        p = no_links(out / name)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    print(json.dumps({"parts": len(chunks), "archive_sha256": digest(archive), "package_files": len(files), "all_sha256_match": True, "safe_regular_files_only": True, "engine_run": False}))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify the retained E1 stage, then optionally copy only this pinned R1 leaf."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

D = Path(__file__).resolve().parent
R = D.parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--dest", required=True)
parser.add_argument("--apply", action="store_true", help="Copy the pinned new leaf after all preconditions pass")
parser.add_argument("--receipt", help="Optional absolute result JSON path owned by the coordinator")
args = parser.parse_args()
destination = Path(args.dest).resolve()
if destination == R or R in destination.parents or not (destination / "project.godot").is_file():
    raise SystemExit("Existing separate ordinary E1 stage required")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_relative(value):
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or ".godot" in path.parts:
        raise SystemExit("Invalid closure path " + value)
    return path


binding_path = D / "source_binding.json"
binding = json.loads(binding_path.read_text())
receipt_path = R / safe_relative(binding["parent_stage_receipt"]["path"])
if sha(receipt_path) != binding["parent_stage_receipt"]["sha256"]:
    raise SystemExit("Retained E1 stage receipt changed")
parent = json.loads(receipt_path.read_text())
if parent["binding_sha256"] != binding["parent_binding_sha256"]:
    raise SystemExit("Parent stage must be the exact current E1 identity")

# No guessed dependency traversal or bulk recopy. The parent's292 canonical
# targets include source-to-target remaps and the existing runtime data closure.
checked_parent = 0
for target, record in parent["closure"].items():
    path = destination / safe_relative(target)
    if not path.is_file() or sha(path) != record["sha256"]:
        raise SystemExit("Parent stage dependency mismatch: " + target)
    checked_parent += 1

files = dict(binding["candidate_files"])
files["source_binding.json"] = sha(binding_path)
plan = []
for relative, expected in files.items():
    source = D / safe_relative(relative)
    if not source.is_file() or sha(source) != expected:
        raise SystemExit("New candidate source pin changed: " + relative)
    target = destination / D.relative_to(R) / relative
    if destination not in target.resolve().parents:
        raise SystemExit("Candidate destination escapes selected stage")
    plan.append((source, target, expected))

copied = 0
if args.apply:
    for source, target, expected in plan:
        if not target.is_file() or sha(target) != expected:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied += 1
        if sha(target) != expected:
            raise SystemExit("New staged source mismatch: " + str(target))

report = {
    "status": "R1_LEAF_COPIED_SHA_VERIFIED" if args.apply else "R1_LEAF_PREFLIGHT_READY_NO_COPY",
    "stage": str(destination), "parent_targets_verified": checked_parent,
    "candidate_files": len(plan), "copied": copied,
    "source_binding_sha256": sha(binding_path), "engine_or_import_invoked": False,
    "ordinary_entry_changed": False, "copy_godot_cache": False,
    "closure": {str(target.relative_to(destination)): digest for _, target, digest in plan},
}
if args.receipt:
    output = Path(args.receipt)
    if not output.is_absolute(): raise SystemExit("Receipt path must be absolute")
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False, indent=2))

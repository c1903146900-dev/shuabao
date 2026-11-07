"""Build a new isolated pack after the current guarded runtime has finished.

Never starts an engine, alters a guard, or changes accepted runtimes. The source
identity is deliberately combo12 only; a later accepted baseline needs review.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import struct
import sys

from prepare_overlay import BASE, HERE, OUTPUT, REL, ROOT, digest, prepare, require

REBUILD = ROOT / "rebuild_20261106"
MANIFEST = "first_hero_full_admission_20261020/manifest.json"
GENERATION = "release_generation_20261020/generation.gd"
EXPECTED_MANIFEST = "804e5671f9c27bd99d3144de5de85410860b2fdf28d3a224a9d8acd80baaa841"
EXPECTED_BASE_PACK = "f400fce7fbfc1468c071d5896741345ad1ca6ffb30ccff19e597a41f29ea38e0"


def files(root):
    return {p.relative_to(root).as_posix(): p for p in root.rglob("*") if p.is_file()}


def main(tag):
    require(re.fullmatch(r"boss_motion_combo12_draft[0-9]+", tag) is not None, "Output must be a new boss_motion_combo12_draftNN tag")
    out = REBUILD / tag
    require(not out.exists(), "Refusing to overwrite an existing output")
    review = prepare(check=True)
    base_files = files(BASE)
    manifest_bytes = (BASE / MANIFEST).read_bytes()
    require(digest(manifest_bytes) == EXPECTED_MANIFEST, "Baseline manifest identity changed")
    source_manifest = json.loads(manifest_bytes)
    source_descriptor = json.loads((BASE.parent / "boot/descriptor.json").read_text())
    require(source_descriptor["packs"][0]["sha256"] == EXPECTED_BASE_PACK, "Baseline descriptor identity changed")
    require(source_descriptor["binding_manifest_sha256"] == EXPECTED_MANIFEST, "Baseline descriptor binding changed")
    source_hashes = {rel: digest(p.read_bytes()) for rel, p in base_files.items()}
    expected_sealed = {"res://" + rel: sha for rel, sha in source_hashes.items() if rel not in [MANIFEST, GENERATION]}
    require(source_manifest["files"] == expected_sealed, "Baseline runtime does not exactly match its manifest")
    runtime = out / "runtime"
    shutil.copytree(BASE, runtime)
    shutil.copyfile(OUTPUT, runtime / REL)
    copied = files(runtime)
    require(copied.keys() == base_files.keys(), "Unexpected runtime file additions/removals")
    changes = [rel for rel, p in copied.items() if digest(p.read_bytes()) != source_hashes[rel]]
    require(changes == [REL], "Unexpected pre-seal runtime changes: " + repr(changes))
    # Preserve the existing isolated-release seal and pack format.
    manifest_path = runtime / MANIFEST
    generation_path = runtime / GENERATION
    source_manifest["files"] = {"res://" + p.relative_to(runtime).as_posix(): digest(p.read_bytes()) for p in sorted(runtime.rglob("*")) if p.is_file() and p not in [manifest_path, generation_path]}
    manifest_path.write_text(json.dumps(source_manifest, ensure_ascii=False, indent=2) + "\n")
    manifest_sha = digest(manifest_path.read_bytes())
    generation, count = re.subn(r'const MANIFEST_SHA := "[a-f0-9]{64}"', 'const MANIFEST_SHA := "' + manifest_sha + '"', generation_path.read_text())
    require(count == 1, "Generation manifest pin not unique")
    generation_path.write_text(generation)
    boot = out / "boot"
    boot.mkdir()
    for name in ["boot.gd", "boot.tscn", "project.godot"]:
        shutil.copyfile(REBUILD / "boot234" / name, boot / name)
    data = bytearray()
    entries = []
    for p in sorted(runtime.rglob("*")):
        if not p.is_file():
            continue
        data.extend(bytes((-len(data)) % 16))
        blob = p.read_bytes()
        entries.append((p.relative_to(runtime).as_posix(), len(data), len(blob), hashlib.md5(blob).digest()))
        data.extend(blob)
    data.extend(bytes((-len(data)) % 16))
    header = struct.pack("<6IQQ", 0x43504447, 3, 4, 6, 3, 2, 112, 112 + len(data)) + bytes(72)
    directory = bytearray(struct.pack("<I", len(entries)))
    for name, offset, size, md5 in entries:
        encoded = name.encode()
        encoded += bytes((-len(encoded)) % 4)
        directory.extend(struct.pack("<I", len(encoded)) + encoded + struct.pack("<QQ", offset, size) + md5 + struct.pack("<I", 0))
    pack = boot / "packs/runtime.pck"
    pack.parent.mkdir()
    pack.write_bytes(header + data + directory)
    descriptor = json.loads((REBUILD / "boot234/release_template.json").read_text())
    pack_sha = digest(pack.read_bytes())
    descriptor["packs"][0].update(path=str(pack.resolve()), sha256=pack_sha)
    descriptor["script_paths"] = ["res://" + name for name, _, _, _ in entries if name.endswith(".gd")]
    descriptor["binding_manifest_sha256"] = manifest_sha
    descriptor["resolved_manifests"] = {"res://" + MANIFEST: manifest_sha}
    (boot / "descriptor.json").write_text(json.dumps(descriptor, ensure_ascii=False, indent=2))
    final_files = files(runtime)
    changed = sorted(rel for rel, p in final_files.items() if digest(p.read_bytes()) != source_hashes[rel])
    require(changed == sorted([REL, MANIFEST, GENERATION]), "Unexpected final runtime changes")
    review.update({"status": "isolated_pack_built_not_engine_tested", "pack_built": True, "output": str(out), "pack_sha256": pack_sha, "manifest_sha256": manifest_sha, "runtime_changed_files": changed, "sealed_entries_verified": len(source_manifest["files"])})
    (out / "rebase_receipt.json").write_text(json.dumps(review, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(review, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    require(len(sys.argv) == 2, "Usage: python -B build_isolated.py boss_motion_combo12_draft01")
    main(sys.argv[1])

#!/usr/bin/env python3
"""Prepare a three-file P3 admission overlay without executing Godot.

Decode Godot Variant containers losslessly; retain every original scalar's
header, representation, padding, string-vs-StringName type, and key order.
Only four runtime_candidates arrays may change. Never edit the source tree.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
import re
import struct


EXPECTED = {
    "fengli_route_20261024/binding.gd": "01e500813669a3258975747c99f0ca189069c95dd38bf02167d622fdc76c7104",
    "__clean_fengli/machine_templates.bin": "4af1f4ecc72684a027101b6f72f4447cd2e2568ffd52b4965e503c652ed73839",
    "__clean_fengli/machine_template_pins.gd": "e96994f1332387a2b1c03a1376003a5f3dca6172142ded1ae59b296d74cfd6f2",
}
BEFORE = ["P1", "P2", "Q1", "Q2", "Q3", "E1", "E2", "E3", "R1", "R2"]
AFTER = ["P1", "P2", "P3", "Q1", "Q2", "Q3", "E1", "E2", "E3", "R1", "R2"]
PHASES = ["constructor", "commerce_bound", "floor_bound"]
PATCH_PATHS = [("runtime_candidates",)] + [
    ("phases", phase, "runtime_candidates") for phase in PHASES
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass
class Node:
    header: int
    scalar: object = None
    original_scalar: bytes = b""
    count_flags: int = 0
    children: list = field(default_factory=list)

    @property
    def kind(self) -> int:
        return self.header & 0xFFFF

    def encode(self) -> bytes:
        if self.kind not in (27, 28):
            return self.original_scalar
        out = bytearray(struct.pack("<II", self.header, self.count_flags | len(self.children)))
        if self.kind == 27:
            for key, value in self.children:
                out.extend(key.encode())
                out.extend(value.encode())
        else:
            for value in self.children:
                out.extend(value.encode())
        return bytes(out)

    def value(self):
        if self.kind == 27:
            pairs = [(key.value(), value.value()) for key, value in self.children]
            assert len({key for key, _ in pairs}) == len(pairs), "duplicate dictionary keys"
            return dict(pairs)
        if self.kind == 28:
            return [child.value() for child in self.children]
        return self.scalar

    def item(self, name: str) -> "Node":
        assert self.kind == 27
        found = [value for key, value in self.children if key.value() == name]
        assert len(found) == 1, (name, len(found))
        return found[0]


class Decoder:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def unpack(self, fmt: str):
        size = struct.calcsize("<" + fmt)
        assert self.pos + size <= len(self.data), "truncated scalar"
        value = struct.unpack_from("<" + fmt, self.data, self.pos)[0]
        self.pos += size
        return value

    def get(self, depth: int = 0) -> Node:
        assert depth < 100, "excessive nesting"
        start = self.pos
        header = self.unpack("I")
        node = Node(header)
        kind = node.kind
        wide = bool(header & (1 << 16))
        if kind in (27, 28):
            # Only untyped Array/Dictionary occur in this pinned template.
            assert header == kind, ("unsupported container flags", hex(header))
            count = self.unpack("I")
            node.count_flags = count & 0x80000000
            count &= 0x7FFFFFFF
            assert count <= len(self.data) // 4, "impossible container length"
            if kind == 27:
                node.children = [(self.get(depth + 1), self.get(depth + 1)) for _ in range(count)]
            else:
                node.children = [self.get(depth + 1) for _ in range(count)]
            return node
        if kind == 0:
            node.scalar = None
        elif kind == 1:
            raw = self.unpack("I")
            assert raw in (0, 1)
            node.scalar = bool(raw)
        elif kind == 2:
            node.scalar = self.unpack("q" if wide else "i")
        elif kind == 3:
            node.scalar = self.unpack("d" if wide else "f")
        elif kind in (4, 21):
            length = self.unpack("I")
            padded = (length + 3) & ~3
            assert self.pos + padded <= len(self.data), "truncated string"
            node.scalar = self.data[self.pos:self.pos + length].decode("utf-8")
            self.pos += padded
        elif kind in (5, 9):
            node.scalar = tuple(self.unpack("d" if wide else "f") for _ in range(2 if kind == 5 else 3))
        else:
            raise ValueError(f"Unsupported Variant type {kind} at byte {start}; no output written")
        node.original_scalar = self.data[start:self.pos]
        return node


def decode(data: bytes) -> Node:
    decoder = Decoder(data)
    root = decoder.get()
    assert decoder.pos == len(data), ("trailing bytes", decoder.pos, len(data))
    assert root.encode() == data, "lossless roundtrip failed"
    return root


def at(root: Node, path: tuple[str, ...]) -> Node:
    for key in path:
        root = root.item(key)
    return root


def changed_paths(a, b, path=()):
    if type(a) is not type(b):
        return [path]
    if isinstance(a, dict):
        assert list(a) == list(b), ("dictionary keys/order changed", path)
        return [item for key in a for item in changed_paths(a[key], b[key], path + (key,))]
    if isinstance(a, list):
        if len(a) != len(b):
            return [path]
        return [item for i in range(len(a)) for item in changed_paths(a[i], b[i], path + (str(i),))]
    return [] if a == b else [path]


def prepare(source: Path, output: Path, report_path: Path):
    source = source.resolve(strict=True)
    output = output.resolve()
    report_path = report_path.resolve()
    assert not output.exists(), "use a fresh overlay directory"
    assert not report_path.exists(), "do not overwrite existing report"
    assert not output.is_relative_to(source) and not source.is_relative_to(output)
    assert not report_path.is_relative_to(source) and not report_path.is_relative_to(output)
    originals = {name: (source / name).read_bytes() for name in EXPECTED}
    for name, value in originals.items():
        assert sha(value) == EXPECTED[name], ("unexpected baseline", name, sha(value))

    template_name = "__clean_fengli/machine_templates.bin"
    raw = originals[template_name]
    root = decode(raw)
    before = root.value()
    assert list(before["phases"]) == PHASES
    preserved_array_bytes = []
    for path in PATCH_PATHS:
        arr = at(root, path)
        assert arr.kind == 28 and arr.value() == BEFORE, path
        preserved_array_bytes.append(arr.encode())
        sample = arr.children[1]
        assert sample.kind == 4 and sample.value() == "P2"
        # Same String encoding/header as its sibling; P2 and P3 are two ASCII bytes.
        new_raw = struct.pack("<II", sample.header, 2) + b"P3\0\0"
        arr.children.insert(2, decode(new_raw))
    patched = root.encode()
    parsed = decode(patched)
    after = parsed.value()
    assert set(changed_paths(before, after)) == set(PATCH_PATHS)
    for path in PATCH_PATHS:
        assert at(parsed, path).value() == AFTER
    # Remove the four inserted values and require the entire original byte stream.
    for path in PATCH_PATHS:
        at(parsed, path).children.pop(2)
    assert parsed.encode() == raw, "reverse edit did not recover exact original bytes"
    assert len(patched) == len(raw) + 4 * 12

    binding_name = "fengli_route_20261024/binding.gd"
    old_line = b'const CANDIDATES = ["P1","P2","Q1","Q2","Q3","E1","E2","E3","R1","R2"]'
    new_line = b'const CANDIDATES = ["P1","P2","P3","Q1","Q2","Q3","E1","E2","E3","R1","R2"]'
    assert originals[binding_name].count(old_line) == 1
    binding = originals[binding_name].replace(old_line, new_line)
    assert binding.replace(new_line, old_line) == originals[binding_name]
    pin_name = "__clean_fengli/machine_template_pins.gd"
    old_pin = f'const SHA256 = "{sha(raw)}"'.encode()
    new_pin = f'const SHA256 = "{sha(patched)}"'.encode()
    assert originals[pin_name].count(old_pin) == 1
    pins = originals[pin_name].replace(old_pin, new_pin)
    assert pins.replace(new_pin, old_pin) == originals[pin_name]
    outputs = {binding_name: binding, template_name: patched, pin_name: pins}

    # P3-dependent Hexes would gain availability through the existing dependency
    # guard. Report all such definitions rather than assuming the change is isolated.
    dependencies = {}
    for phase in PHASES:
        cfg = before["phases"][phase]
        dependencies[phase] = {
            key: value for key, value in cfg["hexes"].items()
            if "P3" in value.get("skill_dependencies", []) or value.get("requires") == "P3"
        }
    report = {
        "status": "STATIC_ONLY_NOT_RUNTIME_ACCEPTANCE",
        "source": str(source),
        "overlay": str(output),
        "changed_files": {name: {"before_sha256": sha(originals[name]), "after_sha256": sha(value),
                                 "before_bytes": len(originals[name]), "after_bytes": len(value)}
                          for name, value in outputs.items()},
        "template_changed_paths": [".".join(path) for path in PATCH_PATHS],
        "runtime_candidates_before": BEFORE,
        "runtime_candidates_after": AFTER,
        "checks": {
            "baseline_sha256_pins_match": True,
            "full_original_decode_consumed": True,
            "original_roundtrip_byte_identical": True,
            "patched_roundtrip_byte_identical": True,
            "semantic_diff_exactly_four_candidate_lists": True,
            "reverse_patch_recovers_entire_original_bytes": True,
            "guard_logic_unchanged": True,
            "numeric_and_display_payloads_untouched": True,
            "engine_or_gui_started": False,
        },
        "p3_dependent_hex_definitions": dependencies,
        "progression_rules": before["phases"]["constructor"].get("progression_rules"),
        "p3_definition": before["phases"]["constructor"]["skill_definitions"]["P3"],
        "runtime_source_binding_unchanged": before["phases"]["constructor"]["runtime_source_binding"],
        "integration_note": "Rebuild complete manifest, generation seal and PCK/descriptor with the existing packager. Do not copy these three files into a running or already sealed candidate.",
    }
    # Validate everything before writing any overlay file.
    output.mkdir(parents=True)
    for name, value in outputs.items():
        dest = output / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(value)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    assert sorted(str(p.relative_to(output)) for p in output.rglob("*") if p.is_file()) == sorted(EXPECTED)
    for name, value in originals.items():
        assert (source / name).read_bytes() == value, ("baseline changed", name)
    print(json.dumps({"status": report["status"], "overlay": str(output), "report": str(report_path),
                      "machine_sha256": sha(patched), "p3_dependent_hex_ids": {p: list(v) for p, v in dependencies.items()}}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.source, args.output, args.report)

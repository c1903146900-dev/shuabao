#!/usr/bin/env python3
"""Portable exact training12 template rebuild, no engine or private source inputs.

Inputs: unchanged p3_undo01 runtime, body_definition_v12.json, fresh output folder.
Writes only machine_templates.bin and its SHA pin in that folder. Does not modify
source, guards, config validation, other values, or any packaging manifest.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct

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


def canonical(value):
    if isinstance(value, dict):
        return {key: canonical(v) for key, v in value.items()}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value

def node(value):
    if isinstance(value, dict):
        return Node(27, children=[(node(k), node(v)) for k, v in value.items()])
    if isinstance(value, list):
        return Node(28, children=[node(v) for v in value])
    if value is None:
        header, payload = 0, b""
    elif isinstance(value, bool):
        header, payload = 1, struct.pack("<I", int(value))
    elif isinstance(value, int):
        header = 2 if -(1 << 31) <= value < (1 << 31) else 2 | (1 << 16)
        payload = struct.pack("<i" if header == 2 else "<q", value)
    elif isinstance(value, float):
        assert math.isfinite(value)
        header, payload = 3 | (1 << 16), struct.pack("<d", value)
    elif isinstance(value, str):
        data = value.encode("utf-8")
        header, payload = 4, struct.pack("<I", len(data)) + data + b"\0" * (-len(data) % 4)
    else:
        raise TypeError(type(value))
    return Node(header, scalar=value, original_scalar=struct.pack("<I", header) + payload)

BASE_SHA = "cafff310f093ab6883497a702b2064b1b38ca672eaea559cfd693eec7a7fed49"
TARGET_SHA = "591394df1d7d28c53ee074bdcb1c7701fe941e85a673e028c8da2a0f522a8784"
DEFINITION_SHA = "b73e1d84da5a92c2a6bff23edac280b5e2c440ce4a15fb6aa376b7e1a46b11c7"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("before_runtime", type=Path)
    ap.add_argument("body_definition", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    before_root, output = args.before_runtime.resolve(), args.output.resolve()
    assert output != before_root and before_root not in output.parents and output not in before_root.parents, "output must be separate from source"
    assert not output.exists(), "use a fresh output directory"
    raw = args.body_definition.read_bytes()
    assert sha(raw) == DEFINITION_SHA, "unexpected training definition"
    body = json.loads(raw)
    assert body == canonical(body) and body["cost"] == 900 and len(body["outcomes"]) == 12
    rel = Path("__clean_fengli/machine_templates.bin")
    pin_rel = Path("__clean_fengli/machine_template_pins.gd")
    before = (before_root / rel).read_bytes()
    pins = (before_root / pin_rel).read_bytes()
    assert sha(before) == BASE_SHA and pins.count(BASE_SHA.encode()) == 1
    root = decode(before)
    assert root.encode() == before
    originals = {}
    for phase in ["constructor", "commerce_bound", "floor_bound"]:
        target = root.item("phases").item(phase)
        originals[phase] = target.item("body")
        for i, (key, _) in enumerate(target.children):
            if key.value() == "body":
                target.children[i] = (key, node(body))
    after = root.encode()
    assert sha(after) == TARGET_SHA and decode(after).encode() == after
    for phase, original in originals.items():
        target = root.item("phases").item(phase)
        for i, (key, _) in enumerate(target.children):
            if key.value() == "body":
                target.children[i] = (key, original)
    assert root.encode() == before, "three-subtree inverse must restore every byte"
    patched_pins = pins.replace(BASE_SHA.encode(), TARGET_SHA.encode())
    (output / rel).parent.mkdir(parents=True)
    (output / rel).write_bytes(after)
    (output / pin_rel).write_bytes(patched_pins)
    assert (before_root / rel).read_bytes() == before and (before_root / pin_rel).read_bytes() == pins
    print(json.dumps({"template_sha256": sha(after), "pins_sha256": sha(patched_pins), "roundtrip_and_inverse_byte_exact": True, "source_unchanged": True, "output": str(output)}))

if __name__ == "__main__":
    main()

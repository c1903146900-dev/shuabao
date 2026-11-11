#!/usr/bin/env python3
"""Portable G02 build: unchanged equipment_hex01 runtime + safe G02 definition +
sealed new route Sim -> separate 3-file template/binding/pin overlay. No engine,
private source tables, guard modifications, or baseline writes.
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


BASE_SHA="591394df1d7d28c53ee074bdcb1c7701fe941e85a673e028c8da2a0f522a8784"
BASE_SIM="65941fb596201cdaba1ed6cf2984e46ff4dc4f89d5c12193ebb57bc820e13de4"
NEW_SIM="12017a7d0fc7a7e1231b19a2c63664566fbaef4c729dd41d92aae8113b0c2c6b"
DEFINITION_SHA="44572b12ca35b3cb4ac991c419a8466e7e354dd3f36c66f71c9c1a25c9d1558a"
def sha(data):return hashlib.sha256(data).hexdigest()
def replace_item(container,key,value):
 for i,(k,v) in enumerate(container.children):
  if k.value()==key:
   container.children[i]=(k,value);return v
 raise KeyError(key)
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument("before_runtime",type=Path);ap.add_argument("definition",type=Path);ap.add_argument("sealed_sim",type=Path);ap.add_argument("output",type=Path)
 a=ap.parse_args();before=a.before_runtime.resolve();out=a.output.resolve()
 assert not out.exists(),"use a fresh output directory"
 assert out!=before and before not in out.parents and out not in before.parents
 defraw=a.definition.read_bytes();assert sha(defraw)==DEFINITION_SHA
 data=json.loads(defraw);assert data["format"]=="fengli-g02-admission-1" and data["item_id"]=="final:G02"
 sim=a.sealed_sim.read_bytes();assert sha(sim)==NEW_SIM
 assert sha((before/"fengli_route_20261024/sim.gd").read_bytes())==BASE_SIM
 rel=Path("__clean_fengli/machine_templates.bin");pinrel=Path("__clean_fengli/machine_template_pins.gd");bindrel=Path("fengli_route_20261024/binding.gd")
 raw=(before/rel).read_bytes();pins=(before/pinrel).read_bytes();binding=(before/bindrel).read_bytes()
 assert sha(raw)==BASE_SHA and pins.count(BASE_SHA.encode())==1 and binding.count(BASE_SIM.encode())==1
 tree=decode(raw);original=tree.value()
 assert original["commerce"]["items"]["final:G02"]==data["commerce"]
 stats=tree.item("stats");assert "final:G02" not in stats.value()
 stats.children.append((node("final:G02"),node(data["definition"])))
 old=[]
 for phase in ["constructor","commerce_bound","floor_bound"]:
  cfg=tree.item("phases").item(phase);assert cfg.item("runtime_source_binding").value()==BASE_SIM
  old.append((cfg,replace_item(cfg,"runtime_source_binding",node(NEW_SIM))))
 updated=tree.encode();assert decode(updated).encode()==updated
 semantic=decode(updated).value();del semantic["stats"]["final:G02"]
 for phase in semantic["phases"]:semantic["phases"][phase]["runtime_source_binding"]=BASE_SIM
 assert semantic==original,"unintended semantic edit"
 stats.children.pop()
 for cfg,value in old:replace_item(cfg,"runtime_source_binding",value)
 assert tree.encode()==raw,"inverse must recover every original byte"
 files={rel:updated,pinrel:pins.replace(BASE_SHA.encode(),sha(updated).encode()),bindrel:binding.replace(BASE_SIM.encode(),NEW_SIM.encode())}
 for path,value in files.items():(out/path).parent.mkdir(parents=True,exist_ok=True);(out/path).write_bytes(value)
 assert (before/rel).read_bytes()==raw and (before/pinrel).read_bytes()==pins and (before/bindrel).read_bytes()==binding
 print(json.dumps({"roundtrip_and_inverse_byte_exact":True,"source_unchanged":True,"sim_sha256":NEW_SIM,"outputs":{str(p):sha(b)for p,b in files.items()}}))
if __name__=="__main__":main()

#!/usr/bin/env python3
"""Portable B12/I12 admission: unchanged g02_01 runtime + safe two-item definition
-> separate template/pin overlay. No engine, source Sim, binding, model, guard,
private source tables, or baseline writes. Existing per-five-second mapping only.
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


BASE_SHA="cef74befe6080cab6c9c7d375ba2c416689a3dfa955ab29c9688fb2cf3e77386"
BASE_SIM="12017a7d0fc7a7e1231b19a2c63664566fbaef4c729dd41d92aae8113b0c2c6b"
BASE_BINDING="08e353c05a2050b5b293afd1183b6bda0b2b92119f181c3907396c7e78c71ca7"
DEFINITION_SHA="55af16cc77360ca2b4789098887212d98d5f51453b88f505c908af3fff6d6664"
def sha(data):return hashlib.sha256(data).hexdigest()
def replace_item(container,key,value):
 for i,(k,v) in enumerate(container.children):
  if k.value()==key:
   container.children[i]=(k,value);return v
 raise KeyError(key)
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument("before_runtime",type=Path);ap.add_argument("definition",type=Path);ap.add_argument("output",type=Path)
 a=ap.parse_args();before=a.before_runtime.resolve();out=a.output.resolve()
 assert not out.exists(),"use a fresh output directory"
 assert out!=before and before not in out.parents and out not in before.parents
 defraw=a.definition.read_bytes();assert sha(defraw)==DEFINITION_SHA
 data=json.loads(defraw);assert data["format"]=="fengli-regen-B12-I12-admission-1"
 assert list(data["items"])==["base:B12","intermediate:I12"]
 simrel=Path("fengli_route_20261024/sim.gd");bindrel=Path("fengli_route_20261024/binding.gd")
 sim=(before/simrel).read_bytes();binding=(before/bindrel).read_bytes()
 assert sha(sim)==BASE_SIM and sha(binding)==BASE_BINDING
 rel=Path("__clean_fengli/machine_templates.bin");pinrel=Path("__clean_fengli/machine_template_pins.gd")
 raw=(before/rel).read_bytes();pins=(before/pinrel).read_bytes()
 assert sha(raw)==BASE_SHA and pins.count(BASE_SHA.encode())==1
 tree=decode(raw);original=tree.value();stats=tree.item("stats");old={}
 for id,entry in data["items"].items():
  assert original["commerce"]["items"][id]==entry["commerce"]
  assert stats.item(id).value()==entry["before"]
  old[id]=replace_item(stats,id,node(entry["definition"]))
 updated=tree.encode();assert decode(updated).encode()==updated
 semantic=decode(updated).value()
 for id,previous in old.items():semantic["stats"][id]=previous.value()
 assert semantic==original,"unintended semantic edit"
 # No other original subtree may change even its binary representation.
 after_tree=decode(updated)
 for k,v in tree.children:
  if k.value()!="stats":assert v.encode()==after_tree.item(k.value()).encode()
 for id,previous in old.items():replace_item(stats,id,previous)
 assert tree.encode()==raw,"inverse must recover every original byte"
 files={rel:updated,pinrel:pins.replace(BASE_SHA.encode(),sha(updated).encode())}
 for path,value in files.items():(out/path).parent.mkdir(parents=True,exist_ok=True);(out/path).write_bytes(value)
 for path,value in [(rel,raw),(pinrel,pins),(simrel,sim),(bindrel,binding)]:assert (before/path).read_bytes()==value
 print(json.dumps({"roundtrip_and_inverse_byte_exact":True,"source_unchanged":True,"sim_and_binding_unchanged":True,"only_stats_changed":["base:B12","intermediate:I12"],"outputs":{str(p):sha(b)for p,b in files.items()}}))
if __name__=="__main__":main()

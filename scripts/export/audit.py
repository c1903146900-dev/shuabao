"""Audit standalone unencrypted Godot 4 PCKs and distribution files.
Format reference: godotengine/godot 4.6 core/io/file_access_pack.cpp.
Outputs paths/hashes only, never suspected secret values. No application edits.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PATTERNS = {
    'private_key': rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\r\n]+[A-Za-z0-9+/=]{30,}',
    'github_token': rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})',
    'aws_access_id': rb'AKIA[A-Z0-9]{16}',
    'credential_assignment': rb'(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|password)\s*[=:]\s*[\x22\x27][A-Za-z0-9_+/=-]{20,}',
    'signed_url': rb'(?i)[?&](?:x-amz-signature|x-goog-signature|sig)=[A-Za-z0-9%]{16,}',
}
BANNED = re.compile(r'(^|/)(?:addons|docs|source|preview|editor|shader_cache|tests|node_modules|__pycache__|\.local|\.git|\.codex|\.agents|\.aws)(/|$)|^scripts/(?:mcp|export|validation)/|\.(?:blend\d*|py|log|mp4|md|zip|tpz|pem|key)$|(^|/)(?:\.env(?:\..*)?|export_credentials\.cfg|Xauthority)$', re.I)

def signatures(raw):
    return [name for name, pattern in PATTERNS.items() if re.search(pattern, raw)]

def unpack(path):
    data = path.read_bytes()
    stream = io.BytesIO(data)
    def num(fmt):
        return struct.unpack('<'+fmt, stream.read(struct.calcsize('<'+fmt)))[0]
    assert stream.read(4) == b'GDPC', 'PCK magic'
    version = num('I')
    engine = [num('I') for _ in range(3)]
    flags, base = num('I'), num('Q')
    assert version in (2,3) and flags & ~2 == 0, 'Unsupported/encrypted/sparse PCK'
    if version == 3:
        stream.seek(num('Q'))
    else:
        stream.seek(64, 1)
    count = num('I')
    assert count < 100000, 'Implausible entry count'
    entries = []
    for _ in range(count):
        length = num('I')
        assert 0 < length < 16384
        name = stream.read(length).rstrip(b'\0').decode('utf-8')
        offset, size = num('Q'), num('Q')
        md5 = stream.read(16)
        assert num('I') == 0, 'Unsupported per-file flags'
        offset += base
        assert offset + size <= len(data)
        raw = data[offset:offset+size]
        assert hashlib.md5(raw).digest() == md5, name+' MD5 mismatch'
        normalized = name.removeprefix('res://')
        assert not BANNED.search(normalized), 'Forbidden package entry: '+name
        assert not signatures(raw), 'Credential signature inside package: '+name
        entries.append({'path':name,'bytes':size,'sha256':hashlib.sha256(raw).hexdigest()})
    return {'format':version,'engine':engine,'entries':entries}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',default='.local/export-evidence/package-audit.json')
    args=parser.parse_args()
    tracked=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
    findings=[]
    for name in filter(None,tracked):
        path=ROOT/name
        if path.is_file():
            for pattern in signatures(path.read_bytes()): findings.append({'path':name,'rule':pattern})
    packages=[]
    for platform, executable in [('windows','shuabao-smoke.exe'),('linux','shuabao-headless.x86_64')]:
        folder=ROOT/'build'/platform
        pck=Path(executable).with_suffix('.pck').name
        expected={executable,pck}
        assert {p.name for p in folder.iterdir()} == expected, 'Unexpected distribution files: '+platform
        files=[]
        for name in sorted(expected):
            path=folder/name; raw=path.read_bytes()
            assert not signatures(raw), 'Credential signature in distribution: '+name
            item={'name':name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
            if name.endswith('.pck'):
                item['pck']=unpack(path)
                paths={entry['path'].removeprefix('res://') for entry in item['pck']['entries']}
                assert 'assets/ui/FONT_LICENSE.txt' in paths, 'Missing bundled font license'
                assert 'data/progression/confirmed_rules.json' in paths, 'Missing authoritative point rules'
                assert any(path in paths for path in ('scenes/integration/room.tscn','scenes/integration/room.scn','scenes/integration/room.tscn.remap')), 'Missing playable entry scene'
            files.append(item)
        packages.append({'platform':platform,'bytes':sum(x['bytes'] for x in files),'files':files})
    report={'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'tracked_files_scanned':len(list(filter(None,tracked))), 'credential_findings':findings,
            'scope':'Tracked file bytes and distribution bytes; signature scan is not a proof of absence of all secrets. No environment or user credentials read.',
            'packages':packages}
    output=ROOT/args.output; output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n')
    if findings: raise SystemExit('Credential signatures found; see paths/rules in audit report')
    print('PACKAGE_AUDIT_PASS',[(p['platform'],p['bytes']) for p in packages])

if __name__=='__main__': main()

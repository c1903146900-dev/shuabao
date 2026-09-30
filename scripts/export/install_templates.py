"""Install only matching Windows/Linux x86_64 export templates from official Godot release."""
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

ROOT=Path(__file__).resolve().parents[2]
NAME='Godot_v4.6.3-stable_export_templates.tpz'
URL='https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/'+NAME
# Published digest on godotengine/godot-builds expanded_assets/4.6.3-stable.
SHA256='3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8'
archive=ROOT/'.local/downloads'/NAME
archive.parent.mkdir(parents=True,exist_ok=True)
if not archive.exists():
    temporary=archive.with_suffix('.tpz.partial')
    if temporary.exists():
        raise SystemExit('Partial transfer exists. Finish/verify it or explicitly remove it before retrying.')
    with urllib.request.urlopen(URL,timeout=60) as response, temporary.open('wb') as output:
        shutil.copyfileobj(response,output,length=4*1024*1024)
    temporary.rename(archive)
with archive.open('rb') as source:
    actual=hashlib.file_digest(source,'sha256').hexdigest()
if actual != SHA256:
    raise SystemExit('Official template archive SHA-256 mismatch; nothing extracted')
target=ROOT/'.local/data/godot/export_templates/4.6.3.stable'
target.mkdir(parents=True,exist_ok=True)
names=['version.txt','windows_release_x86_64.exe','windows_debug_x86_64.exe','linux_release.x86_64','linux_debug.x86_64']
receipt={'official_url':URL,'sha256':actual,'template_version':'4.6.3.stable','files':{}}
with zipfile.ZipFile(archive) as bundle:
    for name in names:
        raw=bundle.read('templates/'+name)
        (target/name).write_bytes(raw)
        receipt['files'][name]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
assert (target/'version.txt').read_text().strip()=='4.6.3.stable'
(ROOT/'.local/template-install.json').write_text(json.dumps(receipt,indent=2))
print('TEMPLATES_VERIFIED_AND_INSTALLED',target)

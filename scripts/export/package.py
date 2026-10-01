"""Package previously audited builds from exactly the clean tracked source commit."""
from pathlib import Path
import hashlib,json,subprocess,tarfile,zipfile
ROOT=Path(__file__).resolve().parents[2]
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
commit=git('rev-parse','HEAD')
assert not git('status','--porcelain','--untracked-files=no'), 'Tracked source is dirty; commit before exporting'
audit=json.loads((ROOT/'.local/export-evidence/package-audit.json').read_text())
assert audit['source_commit']==commit,'Export audit is stale'
assert not audit['credential_findings']
out=ROOT/'build/delivery'/commit;out.mkdir(parents=True,exist_ok=True)
artifacts=[]
for package in audit['packages']:
 folder=ROOT/'build'/package['platform']
 for item in package['files']:
  p=folder/item['name'];assert sha(p)==item['sha256'],'Binary changed after audit'
 name='shuabao-'+package['platform']+'-'+commit[:12]
 if package['platform']=='windows':
  archive=out/(name+'.zip')
  with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   for item in package['files']:z.write(folder/item['name'],item['name'])
 else:
  archive=out/(name+'.tar.gz')
  with tarfile.open(archive,'w:gz') as t:
   for item in package['files']:t.add(folder/item['name'],arcname=item['name'],recursive=False)
 artifacts.append({'path':str(archive.relative_to(ROOT)),'bytes':archive.stat().st_size,'sha256':sha(archive),'unpacked_bytes':package['bytes'],'files':[{k:v for k,v in item.items() if k!='pck'} for item in package['files']]})
tracked=git('ls-files','-z').split('\0')
source={name:{'bytes':(ROOT/name).stat().st_size,'sha256':sha(ROOT/name)} for name in tracked if name and (ROOT/name).is_file()}
source_path=out/'source-files.json';source_path.write_text(json.dumps(source,indent=2)+'\n')
recording_path=ROOT/'build/window-play/recording.json'
recording=json.loads(recording_path.read_text()) if recording_path.exists() else None
if recording is not None:
 assert recording['source_commit']==commit and recording['mode']=='standalone Linux desktop export','Video is not this exported commit'
 assert sha(ROOT/'build/window-play/continuous-play.mp4')==recording['video_sha256']
report={'source_commit':commit,'source_tree':git('rev-parse','HEAD^{tree}'),'engine':subprocess.check_output(['godot','--version'],text=True).strip(),'source_manifest_sha256':sha(source_path),'artifacts':artifacts,'package_audit_sha256':sha(ROOT/'.local/export-evidence/package-audit.json'),'runtime':{'linux_headless':'see .local/export-evidence/linux-boot.log','linux_window':'see build/window-play/game.log and recording.json','windows':'NOT RUN; PE and PCK inspection only'},'recording':recording,'credential_scan_scope':audit['scope']}
(out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
(out/'SHA256SUMS').write_text('\n'.join(sha(p)+'  '+p.name for p in sorted(out.iterdir()) if p.is_file() and p.name!='SHA256SUMS')+'\n')
print(json.dumps({'source_commit':commit,'delivery_directory':str(out),'artifacts':artifacts},indent=2))

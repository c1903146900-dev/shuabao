#!/usr/bin/env python3
"""Only this candidate's additive files and TWO reversible stage entry aliases."""
from pathlib import Path
import argparse,json,shutil
from verify_source import D,R,P,PARENT_SHA,sha,verify,relative,encode
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True)
mode=p.add_mutually_exclusive_group();mode.add_argument('--temporary-apply',action='store_true');mode.add_argument('--restore',action='store_true')
p.add_argument('--backup-dir',type=Path);p.add_argument('--exit-receipt',type=Path,action='append',default=[]);p.add_argument('--no-engine-started',action='store_true');p.add_argument('--receipt',type=Path,required=True);a=p.parse_args()
source=verify();S=a.stage.resolve();assert S!=R and R not in S.parents and (S/'project.godot').is_file()
binding=json.loads((D/'source_binding.json').read_text());parent=json.loads((P/'source_binding.json').read_text());changes=binding['ancestor_pin_replacements']
assert sha(S/P.relative_to(R)/'source_binding.json')==PARENT_SHA
def non_entry_pins():
 for key,digest in parent['runtime_map'].items():
  if key not in changes:assert sha(S/relative(key))==digest,'unrelated parent stage changed: '+key
non_entry_pins()
own_prefix='res://'+str(D.relative_to(R))+'/'
new={k:v for k,v in binding['runtime_map'].items() if k.startswith(own_prefix)}
new[own_prefix+'source_binding.json']=sha(D/'source_binding.json')
result={'schema':'ink-river-frontdoor-stage-alias-1','source_binding_sha256':sha(D/'source_binding.json'),'stage':str(S),'production_R_changed':False,'entry_whitelist':changes,'additive_files':len(new)}
if a.restore:
 assert a.backup_dir is not None
 B=a.backup_dir.resolve();saved=json.loads((B/'BACKUP.json').read_text())
 assert saved['stage']==str(S) and saved['source_binding_sha256']==sha(D/'source_binding.json')
 assert bool(a.exit_receipt)!=bool(a.no_engine_started),'supply reaped process receipts OR explicit no-engine-started'
 processes=[]
 for path in a.exit_receipt:
  receipt=json.loads(path.read_text())
  assert receipt.get('reaped') is True and receipt.get('cleanup_group_empty') is True and receipt.get('group_final')==[],'process not fully reaped/empty: '+str(path)
  processes.append({'path':str(path),'sha256':sha(path),'pid':receipt.get('pid'),'exit':receipt.get('exit'),'namespace':receipt.get('desktop_pid_namespace')})
 for key,change in changes.items():
  entry=saved['entries'][key];backup=B/entry['file'];assert sha(backup)==change['before'] and entry['sha256']==change['before']
  assert sha(S/relative(key)) in [change['before'],change['after']],'refuse to overwrite unrelated stage entry change'
 for key,change in changes.items():
  shutil.copyfile(B/saved['entries'][key]['file'],S/relative(key));assert sha(S/relative(key))==change['before']
 for key,digest in parent['runtime_map'].items():assert sha(S/relative(key))==digest,'parent closure not restored: '+key
 result.update({'status':'TWO_STAGE_ENTRY_PREIMAGES_RESTORED','backup':str(B),'process_receipts':processes,'no_engine_started':a.no_engine_started,'previous_parent_runtime_map_restored':True,'candidate_new_entry_binding_admitted_after_restore':False,'entries_after':{k:sha(S/relative(k)) for k in changes}})
else:
 for key,change in changes.items():assert sha(S/relative(key))==change['before'],'fresh staging requires exact old two entries'
 for key,digest in new.items():
  target=S/relative(key);assert S in target.resolve().parents
  if target.exists():assert sha(target)==digest,'existing candidate file differs: '+key
 if not a.temporary_apply:
  result.update({'status':'TEMPORARY_STAGE_ALIAS_PREFLIGHT','entries_after':{k:sha(S/relative(k)) for k in changes}})
 else:
  assert a.backup_dir is not None
  B=a.backup_dir.resolve();assert not B.exists(),'never overwrite a prior entry backup';B.mkdir(parents=True)
  saved={'schema':'ink-river-frontdoor-two-entry-backup-1','stage':str(S),'source_binding_sha256':sha(D/'source_binding.json'),'entries':{}}
  for index,(key,change) in enumerate(changes.items()):
   name='entry_%d.gd'%index;shutil.copyfile(S/relative(key),B/name);assert sha(B/name)==change['before'];saved['entries'][key]={'file':name,'sha256':change['before']}
  (B/'BACKUP.json').write_text(encode(saved));copied=[]
  for key,digest in new.items():
   target=S/relative(key)
   if target.exists():continue
   target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/relative(key),target);assert sha(target)==digest;copied.append(key)
  try:
   for key,change in changes.items():
    planned=R/binding['source_aliases'][str(relative(key))];shutil.copyfile(planned,S/relative(key));assert sha(S/relative(key))==change['after']
   for key,digest in binding['runtime_map'].items():assert sha(S/relative(key))==digest,key
  except Exception:
   for key in changes:shutil.copyfile(B/saved['entries'][key]['file'],S/relative(key))
   a.receipt.write_text(encode(result|{'status':'APPLY_FAILED_ENTRIES_ROLLED_BACK','backup':str(B),'entries_after':{k:sha(S/relative(k)) for k in changes}}))
   raise
  result.update({'status':'TWO_STAGE_ENTRY_ALIASES_TEMPORARILY_APPLIED','backup':str(B),'copied':copied,'entries_after':{k:sha(S/relative(k)) for k in changes},'restore_required_after_reaping':True})
a.receipt.write_text(encode(result));print(encode(result),end='')

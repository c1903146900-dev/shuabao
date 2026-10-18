"""Fixed official-import adapter over the sealed functional ownership controller."""
import argparse, hashlib, importlib.util, json, os
from pathlib import Path
from types import SimpleNamespace

RUNTIME_SEAL = '036f5b3b933aad953b46b7a14aa1444f79118e594a1f1082f397dd1fe491e965'
SUPPORT = Path(__file__).resolve().parent.parent/'runtime_support'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def load_guard():
    seal=SUPPORT/'RUNTIME_PINS.json'
    if sha(seal)!=RUNTIME_SEAL:raise RuntimeError('runtime_seal_changed')
    for rel,row in json.loads(seal.read_text())['files'].items():
        p=SUPPORT/rel
        if p.is_symlink() or p.stat().st_size!=row['bytes'] or sha(p)!=row['sha256']:raise RuntimeError('runtime_changed:'+rel)
    swap=SUPPORT.parent/'runtime_swapfix01'
    swap_seal=swap/'SWAPFIX_PINS.json'
    if sha(swap_seal)!='4801f5a92a65f26d629f7e1b920b4ceb932150a133e4f786aefefcc6a64954f5':raise RuntimeError('swapfix_seal_changed')
    if any(p.name=='__pycache__' or p.suffix in ('.pyc','.pyo') for p in swap.rglob('*')):raise RuntimeError('unexpected_swapfix_bytecode')
    for rel,row in json.loads(swap_seal.read_text())['files'].items():
        p=swap/rel
        if p.is_symlink() or p.stat().st_size!=row['bytes'] or sha(p)!=row['sha256']:raise RuntimeError('swapfix_changed:'+rel)
    spec=importlib.util.spec_from_file_location('sealed_owned_runtime',swap/'owned_runtime_guard.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def inventory(root):
    result={}
    if root.is_symlink() or not root.is_dir():raise RuntimeError('invalid_tree_root')
    for p in root.rglob('*'):
        if p.is_symlink():raise RuntimeError('symlink_forbidden:'+p.relative_to(root).as_posix())
        if p.is_file():result[p.relative_to(root).as_posix()]=sha(p)
        elif not p.is_dir():raise RuntimeError('special_file_forbidden')
    return result

def read_pins(path, expected):
    if sha(path)!=expected:raise RuntimeError('input_manifest_changed')
    pins=json.loads(Path(path).read_text())
    if not isinstance(pins,dict) or not pins:raise RuntimeError('invalid_pins')
    for rel,digest in pins.items():
        p=Path(rel)
        if p.is_absolute() or '..' in p.parts or p.as_posix()!=rel or not isinstance(digest,str) or len(digest)!=64:raise RuntimeError('invalid_pin_entry')
    return pins

def fixed_args(args):
    if args:raise RuntimeError('no_extra_import_flags')
    return ['--editor','--import','--quit']

def post_diff(before,after):
    removed=sorted(set(before)-set(after))
    changed=[{'path':p,'before':before[p],'after':after[p]} for p in sorted(set(before)&set(after)) if before[p]!=after[p]]
    added=sorted(set(after)-set(before)); forbidden=[]
    for rel in added:
        p=Path(rel)
        cache=len(p.parts)>1 and p.parts[0]=='.godot'
        sidecar=p.suffix in ('.uid','.import') and str(p.with_suffix('')) in before and Path(str(p.with_suffix(''))).suffix in ('.png','.svg','.ttf','.otf','.glb')
        if not (cache or sidecar):forbidden.append(rel)
    return {'removed':removed,'changed':changed,'added':added,'forbidden_added':forbidden,'accepted':not removed and not changed and not forbidden}

class ImportTransaction:
    def __init__(self,config):
        self.config=config;self.source=Path(config['source']).resolve();self.stage=Path(config['project']).resolve();self.out=Path(config['out']).resolve();self.calls=0
        if self.source==self.stage or self.source in self.stage.parents or self.stage in self.source.parents:raise RuntimeError('source_stage_must_be_separate')
        if self.out==self.source or self.source in self.out.parents:raise RuntimeError('output_must_be_outside_source')
        self.source_pins=read_pins(config['source_pins'],config['source_pins_sha256'])
        self.stage_pins=read_pins(config['pins'],config['pins_sha256'])
        if self.source_pins!=self.stage_pins:raise RuntimeError('stage_must_equal_sealed_input')
        # This adapter is intentionally limited to the requested script-free 98-resource closure.
        assets=[p for p in self.stage_pins if p!='project.godot' and not p.endswith('.import')]
        if len(assets)!=98 or len(self.stage_pins)!=197 or 'project.godot' not in self.stage_pins:raise RuntimeError('expected_98_resource_closure')
        if any(Path(p).suffix not in ('.png','.svg','.ttf','.otf','.glb') or p+'.import' not in self.stage_pins for p in assets):raise RuntimeError('unexpected_resource_or_missing_descriptor')

    def verify(self,root,pinfile,expected):
        if Path(root).resolve()!=self.stage or Path(pinfile).resolve()!=Path(self.config['pins']).resolve() or expected!=self.config['pins_sha256']:raise RuntimeError('transaction_binding_changed')
        read_pins(self.config['source_pins'],self.config['source_pins_sha256']);read_pins(pinfile,expected)
        if self.calls==0:
            if inventory(self.source)!=self.source_pins or inventory(self.stage)!=self.stage_pins:raise RuntimeError('pre_input_bytes_changed')
            for rel in self.source_pins:
                a=(self.source/rel).stat();b=(self.stage/rel).stat()
                if a.st_nlink!=1 or b.st_nlink!=1 or (a.st_dev,a.st_ino)==(b.st_dev,b.st_ino):raise RuntimeError('source_stage_hardlink:'+rel)
            self.calls=1;return len(self.stage_pins)
        if self.calls!=1:raise RuntimeError('unexpected_transaction_phase')
        self.calls=2
        source_after=inventory(self.source)
        source_diff=post_diff(self.source_pins,source_after);source_diff['accepted']=source_after==self.source_pins
        stage_after=inventory(self.stage)
        stage_diff=post_diff(self.stage_pins,stage_after)
        stage_diff['added_bytes']=sum((self.stage/rel).stat().st_size for rel in stage_diff['added'])
        stage_diff['total_bytes']=sum((self.stage/rel).stat().st_size for rel in stage_after)
        stage_diff['post_file_count']=len(stage_after)
        post_pins=self.out/'IMPORT_POST_STAGE_PINS.json'
        post_pins.write_text(json.dumps(stage_after,sort_keys=True,indent=2)+'\n')
        stage_diff['post_pins_sha256']=sha(post_pins)
        report={'mode':'official_import','source':source_diff,'stage':stage_diff,'failed_import_cache_not_promoted':True}
        (self.out/'import_diff.json').write_text(json.dumps(report,indent=2)+'\n')
        if not source_diff['accepted'] or not stage_diff['accepted']:raise RuntimeError('official_import_changed_sealed_inputs_see_import_diff')
        return len(self.stage_pins)+len(stage_diff['added'])

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--config',required=True);parser.add_argument('--config-sha256',required=True);args=parser.parse_args()
    if sha(args.config)!=args.config_sha256:raise RuntimeError('config_changed')
    c=json.loads(Path(args.config).read_text())
    required={'source','source_pins','source_pins_sha256','project','pins','pins_sha256','out','binary','binary_sha256'}
    if set(c)!=required:raise RuntimeError('exact_config_fields_required')
    transaction=ImportTransaction(c);guard=load_guard()
    # Preserve guard.run byte-for-byte, including its original shared HERE lock and all cleanup paths.
    guard.functional_args=fixed_args;guard.verify_tree=transaction.verify
    result=guard.run(SimpleNamespace(project=c['project'],out=c['out'],pins=c['pins'],pins_sha256=c['pins_sha256'],binary=c['binary'],binary_sha256=c['binary_sha256'],engine_args=[]))
    print('OFFICIAL_IMPORT_FINAL '+json.dumps(result));return 0 if result['passed'] else 4

if __name__=='__main__':raise SystemExit(main())

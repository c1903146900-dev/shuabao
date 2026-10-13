#!/usr/bin/env python3
"""Read actual external engine evidence only; never creates a success result."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);args=p.parse_args()
sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest()
result=args.stage/'tests/ink_q2_foundation_20261005/fix01/q2_result.json'
assert result.exists(),'Engine result is absent, NOT_RUN'
value=json.loads(result.read_text());log=args.log.read_text()
assert 'INK_Q2_FOUNDATION_REPORT ' in log,'No actual gate report in supplied engine log'
assert not re.search(r'SCRIPT ERROR|Parse Error|ERROR:',log),'Actual engine error present'
assert value['source_binding_sha256']==sha(H/'source_binding.json'),'Wrong candidate binding'
assert value['passed'] and not value['failures'] and value['engine_run'] is True,'Failed or unexecuted gate'
expected={'source_ranks','partial_cd','input_h03','activation_sweep','h04','projectiles','lifecycle','callbacks','pause_and_order','retained'}
assert set(value['completed'])==expected and value['checks']>=100,'Missing finite cases/checks'
assert value['ordinary_entry'] is False and value['normal_input'] is False and value['visual_acceptance'] is False,'Invalid scope promotion'
print(json.dumps({'passed':True,'engine_result':str(result),'checks':value['checks'],'binding':value['source_binding_sha256'],'scope':'finite isolated Q2 mechanics only; no host/UI/art acceptance'},indent=2))

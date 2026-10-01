"""Read-only GLB comparison, independent of authoring (authoring uses Blender MCP)."""
import hashlib,json,struct
from pathlib import Path

def read(path):
 data=Path(path).read_bytes();size=struct.unpack_from('<I',data,12)[0]
 return json.loads(data[20:20+size]),data[28+size:]

def contract(path):
 doc,binary=read(path)
 def accessor(index):
  a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
  start=v.get('byteOffset',0)+a.get('byteOffset',0)
  count=a['count']*{'SCALAR':1,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]*4
  return hashlib.sha256(binary[start:start+count]).hexdigest()
 clips={a['name']:[{'target':doc['nodes'][c['target']['node']]['name'],'path':c['target']['path'],
                    'interpolation':a['samplers'][c['sampler']].get('interpolation','LINEAR'),
                    'input':accessor(a['samplers'][c['sampler']]['input']),
                    'output':accessor(a['samplers'][c['sampler']]['output'])} for c in a['channels']] for a in doc['animations']}
 bones={doc['nodes'][i]['name']:{k:v for k,v in doc['nodes'][i].items() if k!='children'} for skin in doc.get('skins',[]) for i in skin['joints']}
 parents={doc['nodes'][child]['name']:node['name'] for node in doc['nodes'] if node.get('name') in bones for child in node.get('children',[]) if doc['nodes'][child].get('name') in bones}
 return clips,bones,parents

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--before',default='.');p.add_argument('--after',default='.local/mcp-fixture');p.add_argument('--output',required=True);args=p.parse_args()
 report={}
 for kind in ['fengli','minion','elite','boss']:
  directory='assets/fengli' if kind=='fengli' else 'assets/arena/enemies';rel=Path(directory)/(kind+'.glb')
  a,ab,ap=contract(Path(args.before)/rel);b,bb,bp=contract(Path(args.after)/rel)
  report[kind]={'motion_identical':a==b,'rest_bones_identical':ab==bb,'hierarchy_identical':ap==bp,'clips':list(a)}
 Path(args.output).write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
 assert all(v['motion_identical'] and v['rest_bones_identical'] and v['hierarchy_identical'] for v in report.values())

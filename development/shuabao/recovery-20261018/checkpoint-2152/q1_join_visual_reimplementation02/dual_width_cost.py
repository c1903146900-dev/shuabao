from pathlib import Path
ns={"__file__":str(Path(__file__).with_name("obb_cost_experiment.py"))};exec(Path(__file__).with_name('obb_cost_experiment.py').read_text().split('rows=[]')[0],ns)
Cache=ns['Cache'];math=ns['math'];time=ns['time'];json=ns['json'];rows=[]
for shape in ['U','S','near180']:
 for n in [128,256,512]:
  if shape=='U':p=[(2*math.sin(math.pi*i/n),2*(1-math.cos(math.pi*i/n))) for i in range(n+1)]
  elif shape=='S':p=[(4*i/n,math.sin(2*math.pi*i/n)) for i in range(n+1)]
  else:p=[(6*i/n,0) if i<=n//2 else (6*(1-i/n),.002*(2*i/n-1)) for i in range(n+1)]
  for batch in [1,8,32]:
   c=Cache();cost=[]
   ends=list(range(2,len(p)+1,batch))
   if ends[-1]!=len(p):ends.append(len(p))
   for end in ends:
    before=time.perf_counter();c.get(p[:end],1.6);c.get(p[:end],.1,True);cost.append((time.perf_counter()-before)*1000)
   before=time.perf_counter();a=c.get(p,1.6);assert c.get(p,1.6) is a and c.get(p,1.6) is a;release=(time.perf_counter()-before)*1000
   rows.append(dict(shape=shape,points=n+1,motion_batch=batch,total_drag_ms=sum(cost),max_combined_drag_ms=max(cost),release_cached_ms=release))
Path(__file__).with_name('dual_width_cost.json').write_text(json.dumps({'python_only':True,'includes_full_uv_rebuild_each_batch':True,'Godot_mesh_upload_not_measured':True,'measurements':rows},indent=2)+'\n');print(json.dumps(rows))

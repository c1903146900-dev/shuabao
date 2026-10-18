from check_geometry_with_bbox import build
import time,math,json
from pathlib import Path
rows=[]
for shape in ['U','S','near180']:
 for n in [32,128,256]:
  if shape=='U':p=[(2*math.sin(math.pi*i/n),2*(1-math.cos(math.pi*i/n))) for i in range(n+1)]
  elif shape=='S':p=[(4*i/n,math.sin(2*math.pi*i/n)) for i in range(n+1)]
  else:p=[(6*i/n,0) if i<=n//2 else (6*(1-i/n),.002*(2*i/n-1)) for i in range(n+1)]
  before=time.perf_counter();r,t,u=build(p,1.6);elapsed=time.perf_counter()-before
  rows.append({'shape':shape,'points':len(p),'rectangles':len(r),'triangles':len(t),'seconds_python_double':elapsed})
  print(rows[-1],flush=True)
Path(__file__).with_name('dense_geometry_cost.json').write_text(json.dumps({'not_engine_performance':True,'unbounded_sampler':True,'measurements':rows},indent=2)+'\n')

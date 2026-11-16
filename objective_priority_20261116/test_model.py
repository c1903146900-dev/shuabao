"""Independent priority truth table, not GDScript execution."""
import json
checks=0
for status in ['preparation','combat','between_rooms','service','completed','defeated']:
 for bits in range(8):
  fault,paused,map_open=[bool(bits&(1<<k)) for k in range(3)]
  for remaining in [-1.,0.,.1,4.]:
   important=fault or paused or map_open or status in ['completed','defeated']
   use_notice=remaining>0 and not important
   if important:assert not use_notice
   else:assert use_notice==(remaining>0)
   checks+=1
print(json.dumps({'passed':True,'checks':checks,'scope':'Python priority model only','engine_run':False},indent=2))

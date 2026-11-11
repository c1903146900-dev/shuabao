from pathlib import Path
import hashlib, json, math, random, re, difflib
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent/'source/rebuild_20261106/dash_trail01/runtime'
OVER=ROOT/'changes'
checks=0
def check(value,label):
 global checks
 assert value,label
 checks+=1

def function(text,name):
 m=re.search(r'^func '+re.escape(name)+r'\(.*?(?=^func |\Z)',text,re.M|re.S)
 assert m,name
 return m.group(0)
old=(BASE/'fengli_route_20261024/puppet_motion.gd').read_text()
new=(OVER/'fengli_route_20261024/puppet_motion.gd').read_text()
for name in ['blend_curve','progress','pose_key','r1_weight','arm_angle','basic_aim_pitch','dash_thrust','_polygon','body_pose']:
 check(function(old,name)==function(new,name),'unchanged '+name)
old_draw=function(old,'draw_pose'); new_draw=function(new,'draw_pose')
added=''' if kind=="dash_attack_started":
  var aim_pitch:float=dash_aim_pitch(event,age,local_aim)
  receipt.dash_aim_pitch=aim_pitch
  if absf(aim_pitch)>.00001:
   _draw_dash_aim(canvas,texture,vertices,aim_pitch)
   return
'''
check(new_draw.replace(added,'')==old_draw,'original pose deformation identical')
old_pres=(BASE/'fengli_route_20261024/presentation.gd').read_text(); new_pres=(OVER/'fengli_route_20261024/presentation.gd').read_text()
check(new_pres==old_pres.replace('  if str(animation.get("kind",""))=="attack_started":','  if str(animation.get("kind","")) in ["attack_started","dash_attack_started"]:'),'presentation sole local aim change')
check(sorted(str(p.relative_to(OVER)) for p in OVER.rglob('*') if p.is_file())==['fengli_route_20261024/presentation.gd','fengli_route_20261024/puppet_motion.gd'],'only two overlay sources')
# No runtime geometry calls in the drawing helper or angle function.
check('Geometry2D.' not in function(new,'_draw_dash_aim'),'geometry cached')
check('if not dash_aim_parts.is_empty():return' in function(new,'_prepare_dash_aim_parts'),'one-time geometry build')
for token in ['hero.','host.','request_action','schedule_effect','damage_enemy','dash_direction=','real_time=','hero_time=']:
 for name in ['dash_aim_pitch','_prepare_dash_aim_parts','_dash_mesh_point','_draw_dash_aim']:
  check(token not in function(new,name),'no gameplay write '+token)

def smooth(x):
 x=max(0,min(1,x));return x*x*(3-2*x)
def rotate(p,a):
 c,s=math.cos(a),math.sin(a);return (p[0]*c-p[1]*s,p[0]*s+p[1]*c)
def thrust(age):
 if age<C*.45:return -1.
 if age<C:return -1+2*smooth((age-C*.45)/(C*.55))
 return 1-smooth((age-C)/R)
def aim(age,p):
 e=smooth(age/(C*.6))
 if age>C+H:e*=1-smooth((age-C-H)/(R-H))
 return max(-1.35,min(1.05,math.atan2(p[1],p[0])-.17))*e
C=7/60; R=.4-C; H=min(.08,R*.25)
# Test the same pure angle formula; this is not a GDScript runtime invocation.
angles={}
for name,d in [('north',(0,-1)),('south',(0,1)),('east',(1,0)),('west',(-1,0)),('northeast',(1,-1)),('northwest',(-1,-1)),('southeast',(1,1)),('southwest',(-1,1))]:
 for mirror in ([1,-1] if d[0]==0 else [1 if d[0]>0 else -1]):
  samples=[]
  for step in range(401):
   age=step/1000.; t=thrust(age); lean=.10*t*mirror
   p=rotate(d,-lean); p=(p[0]/(mirror*(1+.045*abs(t))),p[1]/(1-.045*abs(t)))
   a=aim(age,p)
   check(math.isfinite(a) and -1.350001<=a<=1.050001,'finite bounded angle')
   samples.append(a)
  check(samples[0]==0 and abs(samples[-1])<1e-12,'zero entry and exit')
  check(max(abs(b-a) for a,b in zip(samples,samples[1:]))<.035,'1ms continuity')
  p=rotate(d,-.1*mirror);p=(p[0]/(mirror*1.045),p[1]/.955)
  contact=aim(C,p)
  angles[name+' mirror '+str(mirror)]=round(contact,9)
  if name=='north':check(contact<-1.2,'visible north pitch')
  if name=='south':check(contact>.9,'visible south pitch')
  for boundary in [C*.6,C,C+H,.4]:
   check(abs(aim(boundary-1e-8,p)-aim(boundary+1e-8,p))<1e-6,'continuous phase boundary')
# Rotations preserve all front-arm pairwise distances at every sampled angle.
rng=random.Random(4112)
for _ in range(2000):
 a=rng.uniform(-1.35,1.05); p=(rng.uniform(-20,45),rng.uniform(-30,25));q=(rng.uniform(-20,45),rng.uniform(-30,25));pivot=(9,-22)
 def transformed(x):
  v=rotate((x[0]-pivot[0],x[1]-pivot[1]),a);return(v[0]+pivot[0],v[1]+pivot[1])
 check(abs(math.dist(p,q)-math.dist(transformed(p),transformed(q)))<1e-12,'rigid added rotation')
# Polygon is simple; selected hand/blade points are in, other body parts out.
mask=[(678,623),(735,588),(788,594),(840,623),(842,667),(1144,716),(1150,796),(1015,802),(886,768),(800,741),(701,733),(650,714),(636,656)]
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def sub(a,b):return(a[0]-b[0],a[1]-b[1])
def inside(p):
 odd=False
 for a,b in zip(mask,mask[1:]+mask[:1]):
  if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:odd=not odd
 return odd
for p in [(710,680),(750,630),(840,710),(1080,750),(1105,750),(706,627)]:check(inside(p),'hand/blade/pivot inside mask')
for p in [(690,500),(780,850),(490,680),(780,770),(620,690)]:check(not inside(p),'head/feet/rear dagger/knee excluded')
for i,(a,b) in enumerate(zip(mask,mask[1:]+mask[:1])):
 for j,(c,d) in enumerate(zip(mask,mask[1:]+mask[:1])):
  if j<=i+1 or (i==0 and j==len(mask)-1):continue
  check(not(cross(sub(b,a),sub(c,a))*cross(sub(b,a),sub(d,a))<0 and cross(sub(d,c),sub(a,c))*cross(sub(d,c),sub(b,c))<0),'simple cutout polygon')
# Barycentric interpolation recovers the original deformed triangle at identity.
for _ in range(2000):
 a=(rng.uniform(-100,100),rng.uniform(-100,100));b=(a[0]+64,a[1]);c=(a[0],a[1]+1024/18)
 v,w=rng.random(),rng.random()
 if v+w>1:v,w=1-v,1-w
 p=(a[0]+64*v,a[1]+1024/18*w);ab=sub(b,a);ac=sub(c,a);ap=sub(p,a)
 vv=cross(ap,ac)/cross(ab,ac);ww=cross(ab,ap)/cross(ab,ac)
 check(abs(vv-v)<1e-12 and abs(ww-w)<1e-12 and abs((1-vv-ww)+vv+ww-1)<1e-12,'identity barycentric reconstruction')
manifest={}
for rel in ['fengli_route_20261024/presentation.gd','fengli_route_20261024/puppet_motion.gd']:
 before=(BASE/rel).read_bytes();after=(OVER/rel).read_bytes()
 manifest[rel]={'before_sha256':hashlib.sha256(before).hexdigest(),'after_sha256':hashlib.sha256(after).hexdigest()}
 patch=''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
 if rel.endswith('presentation.gd'):combined=patch
 else:combined+=patch
(ROOT/'dash_attack_pitch.patch').write_text(combined)
(ROOT/'SOURCE_HASHES.json').write_text(json.dumps(manifest,indent=2)+'\n')
result={'status':'STATIC_CHECKS_PASS_NOT_RUNTIME_VALIDATED','checks':checks,'contact_after':C,'duration':.4,'recovery':R,'hold_after_contact':H,'contact_pitch_radians':angles,'limits':['No engine startup or GDScript compilation performed.','Python formula/geometry checks are not rendered evidence.','Shoulder connection, occlusion, visual picking and performance require guarded runtime review.','No claim of exact blade collision alignment; angle capped to preserve readable silhouette.'],'sources':manifest}
(ROOT/'STATIC_QA.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))

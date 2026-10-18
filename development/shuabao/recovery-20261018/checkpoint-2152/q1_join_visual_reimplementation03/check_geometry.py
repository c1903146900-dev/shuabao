from pathlib import Path
src=Path(__file__).parent.parent/'q1_join_visual_reimplementation02/obb_cost_experiment.py'
ctx={'__file__':str(src)};exec(src.read_text().split('rows=[]')[0].replace('+1e-9:return False','+1e-5*(1+la*abs(dot(da,axis))+wa*abs(dot(sa,axis))+lb*abs(dot(db,axis))+wb*abs(dot(sb,axis))+abs(dot(delta,axis))):return False'),ctx)
base=Path(__file__).parent.parent/'q1_join_visual_reimplementation01/check_geometry.py'
ns=ctx['ns'];ns['__file__']=__file__
# Independent baseline clips still verify union area and overlaps; Cache is new mesh producer.
def build(path,width):
 rects,_,_=ctx['ns']['original_build'](path,width)
 t,u=ctx['Cache']().get(path,width)
 return rects,t,u
ns['original_build']=ns['build'];ns['build']=build
exec(base.read_text()[base.read_text().index('cases='):],ns)

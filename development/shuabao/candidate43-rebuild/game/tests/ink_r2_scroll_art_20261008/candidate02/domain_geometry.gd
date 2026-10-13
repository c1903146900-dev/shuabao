extends RefCounted
## One low-contrast irregular range edge + five OPEN interior brush ribbons.
const SECTIONS: int=64
func build() -> ArrayMesh:
 var vertices := PackedVector3Array();var uvs := PackedVector2Array()
 var strokes := PackedVector2Array();var colors := PackedColorArray()
 var normals := PackedVector3Array();var indices := PackedInt32Array()
 for item: int in range(6):
  var base: int=vertices.size()
  var count: int=SECTIONS if item==0 else 12
  for section: int in range(count+1):
   var along: float=float(section)/float(count)
   var angle: float=along*TAU if item==0 else deg_to_rad(-155.0+float(item-1)*69.0)+0.34*sin(along*PI)
   var radius: float=0.995 if item==0 else 0.94-0.70*along
   var width: float=(0.005+0.005*(0.5+0.5*sin(angle*7.0+0.7))) if item==0 else 0.055*pow(maxf(0.02,sin(along*PI)),0.6)
   for side: int in range(2):
    var point: Vector3=Vector3(cos(angle),0,sin(angle))*(radius-width*float(side))
    point.y=0.018 if item==0 else 0.026
    vertices.append(point);uvs.append(Vector2(lerpf(180,1100,along),552.0+float(side)*62.0)/Vector2(1254,675))
    strokes.append(Vector2(along,float(side)));colors.append(Color(1.0 if item==0 else 0.0,float(item)/6.0,float(side),1.0));normals.append(Vector3.UP)
   if section<count:
    var a: int=base+section*2
    indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs
 arrays[Mesh.ARRAY_TEX_UV2]=strokes;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func geometry_contract() -> Dictionary:
 return {"surfaces":1,"vertices":260,"triangles":248,"fixed_boundary_count":1,"open_ribbons":5,"particles":0}

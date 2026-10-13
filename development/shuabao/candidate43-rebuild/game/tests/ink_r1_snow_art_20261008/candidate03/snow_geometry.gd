extends RefCounted
## Three local snow washes, three authored atlas landscape depths, thin fixed range,
## six broken frost edges, four snow ribbons and one caster-origin brush.
## x/z are source-radius fractions; y stays in metres when the view scales.
const MOUNTAINS: Array = [
 {"x":-0.04,"z":-0.45,"width":1.34,"depth":0.21,"height":1.30,"angle":-0.04,"opacity":0.36,"layer":0.0,"cell":[0.0,0.0,1254.0,675.0],"root":617.0},
 {"x":-0.30,"z":-0.11,"width":0.88,"depth":0.24,"height":1.70,"angle":0.09,"opacity":0.69,"layer":0.5,"cell":[0.0,699.0,648.0,983.0],"root":968.0},
 {"x":0.43,"z":0.21,"width":0.71,"depth":0.19,"height":1.08,"angle":-0.20,"opacity":0.79,"layer":1.0,"cell":[648.0,747.0,1254.0,989.0],"root":973.0}
]
const WASHES: Array = [
 {"x":-0.06,"z":-0.37,"width":1.50,"depth":0.48,"angle":-0.08,"opacity":0.30},
 {"x":-0.35,"z":0.02,"width":0.90,"depth":0.48,"angle":0.18,"opacity":0.25},
 {"x":0.27,"z":0.40,"width":1.10,"depth":0.32,"angle":-0.22,"opacity":0.28}
]
const CONNECTIONS: Array = [
 {"path":[[-0.06,-0.46],[-0.46,-0.42],[-0.49,-0.20],[-0.28,-0.09]],"width":0.095,"opacity":0.28},
 {"path":[[-0.39,-0.10],[-0.19,0.23],[0.04,0.30],[0.46,0.21]],"width":0.115,"opacity":0.34}
]
const CONNECTION_SECTIONS: int = 17
const EDGE_ARCS: Array = [[-175.0,-141.0],[-124.0,-75.0],[-53.0,-9.0],[21.0,51.0],[78.0,119.0],[143.0,165.0]]
const RIBBONS: Array = [
 {"start":[-0.86,0.19],"end":[-0.17,0.51],"bow":-0.07,"width":0.026,"lift":0.046,"phase":0.00,"opacity":0.40},
 {"start":[-0.47,0.66],"end":[0.76,0.17],"bow":0.10,"width":0.030,"lift":0.060,"phase":0.29,"opacity":0.38},
 {"start":[0.28,-0.69],"end":[0.83,-0.19],"bow":0.06,"width":0.023,"lift":0.074,"phase":0.57,"opacity":0.36},
 {"start":[-0.03,0.80],"end":[0.55,0.54],"bow":0.03,"width":0.021,"lift":0.088,"phase":0.81,"opacity":0.34}
]
const OPENING_PATH: Array = [[0.0,0.0],[0.20,-0.05],[-0.22,-0.55],[0.04,-0.79]]
const OPENING_SECTIONS: int = 13
const PREVIEW_SEGMENTS: int = 96

func _append_vertex(buffers: Dictionary, point: Vector3, uv: Vector2, brush: Vector2, metadata: Color) -> void:
 buffers.vertices.append(point)
 buffers.uvs.append(uv)
 buffers.brush.append(brush)
 buffers.colors.append(metadata)
 buffers.normals.append(Vector3.UP)

func _strip_indices(buffers: Dictionary, base: int, sections: int) -> void:
 for section: int in range(sections - 1):
  var a: int = base + section * 2
  buffers.indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))

func _surface(buffers: Dictionary) -> ArrayMesh:
 var arrays: Array = []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = buffers.vertices
 arrays[Mesh.ARRAY_NORMAL] = buffers.normals
 arrays[Mesh.ARRAY_TEX_UV] = buffers.uvs
 arrays[Mesh.ARRAY_TEX_UV2] = buffers.brush
 arrays[Mesh.ARRAY_COLOR] = buffers.colors
 arrays[Mesh.ARRAY_INDEX] = buffers.indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func _buffers() -> Dictionary:
 return {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uvs":PackedVector2Array(),"brush":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}

func build_authored_buffers() -> Dictionary:
 var buffers: Dictionary = _buffers()
 # Three local snow washes, never a full field-sized disk.
 for wash: Dictionary in WASHES:
  var base: int = buffers.vertices.size()
  for row: int in range(3):
   for column: int in range(9):
    var u: float = float(column)/8.0
    var v: float = float(row)/2.0
    var offset := Vector2((u-0.5)*float(wash.width),(v-0.5)*float(wash.depth))
    offset = offset.rotated(float(wash.angle))
    _append_vertex(buffers,Vector3(float(wash.x)+offset.x,0.022,float(wash.z)+offset.y),Vector2(u,v),Vector2(u,v),Color(0.15,0,0,float(wash.opacity)))
  for row: int in range(2):
   for column: int in range(8):
    var k: int = base+row*9+column
    buffers.indices.append_array(PackedInt32Array([k,k+9,k+1,k+1,k+9,k+10]))
 # Shared winding foothills and sparse mist connect the three mountain roots.
 # Two strips per route: low terrain pigment and slightly lifted translucent snow.
 for connection: Dictionary in CONNECTIONS:
  var points: Array = connection.path
  var p0 := Vector2(float(points[0][0]),float(points[0][1]))
  var p1 := Vector2(float(points[1][0]),float(points[1][1]))
  var p2 := Vector2(float(points[2][0]),float(points[2][1]))
  var p3 := Vector2(float(points[3][0]),float(points[3][1]))
  for layer: int in range(2):
   var base: int = buffers.vertices.size()
   for section: int in range(CONNECTION_SECTIONS):
    var u: float = float(section)/float(CONNECTION_SECTIONS-1)
    var t: float = 1.0-u
    var center: Vector2 = p0*t*t*t+p1*3.0*t*t*u+p2*3.0*t*u*u+p3*u*u*u
    var tangent: Vector2 = ((p1-p0)*3.0*t*t+(p2-p1)*6.0*t*u+(p3-p2)*3.0*u*u).normalized()
    var axis := Vector2(-tangent.y,tangent.x)
    var half_width: float = float(connection.width)*(0.65+0.35*sin(PI*u))*(1.0 if layer==0 else 1.40)
    for side: int in range(2):
     var sign_side: float = float(side)*2.0-1.0
     var point: Vector2 = center+axis*half_width*sign_side
     var y: float = 0.045+float(layer)*0.13+0.045*sin(PI*u)
     var kind: float = 0.58 if layer==0 else 0.20
     var opacity: float = float(connection.opacity) if layer==0 else 0.16
     _append_vertex(buffers,Vector3(point.x,y,point.y),Vector2(u,float(side)),Vector2(u,float(side)),Color(kind,0,0,opacity))
   _strip_indices(buffers,base,CONNECTION_SECTIONS)
 # A single thin, variable-width source-range mark. Blue fixes it until expiry.
 var edge_base: int = buffers.vertices.size()
 for section: int in range(97):
  var angle: float = TAU*float(section)/96.0
  var width: float = 0.0035+0.008*pow(0.5+0.5*sin(angle*5.0+0.3*sin(angle*3.0)),2.0)
  for side: int in range(2):
   var radius: float = 1.0-float(side)*width
   _append_vertex(buffers,Vector3(cos(angle)*radius,0.030,sin(angle)*radius),Vector2(float(section)/96.0,float(side)),Vector2(float(section)/96.0,float(side)),Color(0.45,0,1,0.42))
 _strip_indices(buffers,edge_base,97)
 for mountain: Dictionary in MOUNTAINS:
  var base: int = buffers.vertices.size()
  var cell: Array = mountain.cell
  var root: float = float(mountain.root)
  for py: float in [float(cell[1]),root,float(cell[3])]:
   for px: float in [float(cell[0]),(float(cell[0])+float(cell[2]))*0.5,float(cell[2])]:
    var u: float = (px-float(cell[0]))/(float(cell[2])-float(cell[0]))
    var above: float = maxf(0.0,(root-py)/(root-float(cell[1])))
    var offset := Vector2((u-0.5)*float(mountain.width),-(root-py)/(root-float(cell[1]))*float(mountain.depth))
    offset = offset.rotated(float(mountain.angle))
    var fold: float = 0.07*above*sin(u*PI)
    _append_vertex(buffers,Vector3(float(mountain.x)+offset.x,0.05+above*float(mountain.height)+fold,float(mountain.z)+offset.y),Vector2(px,py)/1254.0,Vector2(u,above),Color(0,float(mountain.layer),0,float(mountain.opacity)))
  for row: int in range(2):
   for column: int in range(2):
    var k: int = base+row*3+column
    buffers.indices.append_array(PackedInt32Array([k,k+3,k+1,k+1,k+3,k+4]))
 for arc_index: int in range(EDGE_ARCS.size()):
  var arc: Array = EDGE_ARCS[arc_index]
  var base: int = buffers.vertices.size()
  for section: int in range(7):
   var along: float = float(section)/6.0
   var angle: float = deg_to_rad(lerpf(float(arc[0]),float(arc[1]),along))
   var width: float = (0.006+0.028*sin(PI*along))*(0.82+0.05*float(arc_index%3))
   for side: int in range(2):
    var distance: float = 1.0-float(side)*width
    var point := Vector3(cos(angle)*distance,0.10,sin(angle)*distance)
    _append_vertex(buffers,point,Vector2(lerpf(140.0,1130.0,along)/1254.0,(551.0+float(side)*54.0)/675.0),Vector2(along,float(side)),Color(0.333333,float(arc_index)/6.0,0.0,0.48))
  _strip_indices(buffers,base,7)
 for ribbon: Dictionary in RIBBONS:
  var base: int = buffers.vertices.size()
  var start := Vector2(float(ribbon.start[0]),float(ribbon.start[1]))
  var finish := Vector2(float(ribbon.end[0]),float(ribbon.end[1]))
  var tangent: Vector2 = (finish-start).normalized()
  var cross_axis := Vector2(-tangent.y,tangent.x)
  for section: int in range(7):
   var along: float = float(section)/6.0
   var center: Vector2 = start.lerp(finish,along)+cross_axis*sin(PI*along)*float(ribbon.bow)
   var half_width: float = float(ribbon.width)*(0.26+0.74*sin(PI*along))
   for side_sign: float in [-1.0,1.0]:
    var point: Vector2 = center+cross_axis*half_width*side_sign
    var uv := Vector2(lerpf(150.0,1110.0,along)/1254.0,(580.0+side_sign*23.0)/675.0)
    _append_vertex(buffers,Vector3(point.x,float(ribbon.lift),point.y),uv,Vector2(along,side_sign),Color(0.666667,float(ribbon.phase),0.0,float(ribbon.opacity)))
  _strip_indices(buffers,base,7)
 var opening_base: int = buffers.vertices.size()
 var p0 := Vector2(float(OPENING_PATH[0][0]),float(OPENING_PATH[0][1]))
 var p1 := Vector2(float(OPENING_PATH[1][0]),float(OPENING_PATH[1][1]))
 var p2 := Vector2(float(OPENING_PATH[2][0]),float(OPENING_PATH[2][1]))
 var p3 := Vector2(float(OPENING_PATH[3][0]),float(OPENING_PATH[3][1]))
 for section: int in range(OPENING_SECTIONS):
  var along: float = float(section)/float(OPENING_SECTIONS-1)
  var rest: float = 1.0-along
  var center: Vector2 = p0*rest*rest*rest+p1*3.0*rest*rest*along+p2*3.0*rest*along*along+p3*along*along*along
  var tangent: Vector2 = ((p1-p0)*3.0*rest*rest+(p2-p1)*6.0*rest*along+(p3-p2)*3.0*along*along).normalized()
  var cross_axis := Vector2(-tangent.y,tangent.x)
  var half_width: float = 0.050*(0.28+0.72*sin(PI*along))
  for side_sign: float in [-1.0,1.0]:
   var point: Vector2 = center+cross_axis*half_width*side_sign
   var uv := Vector2(lerpf(120.0,1180.0,along)/1254.0,(575.0+side_sign*22.0)/675.0)
   _append_vertex(buffers,Vector3(point.x,0.034,point.y),uv,Vector2(along,side_sign),Color(1.0,0.0,0.0,1.0))
 _strip_indices(buffers,opening_base,OPENING_SECTIONS)
 return buffers

func build() -> ArrayMesh:
 return _surface(build_authored_buffers())

func build_preview() -> ArrayMesh:
 # Unchanged amber uncommitted boundary; never the snow-domain artwork.
 var buffers: Dictionary = _buffers()
 for section: int in range(PREVIEW_SEGMENTS+1):
  var angle: float = TAU*float(section)/float(PREVIEW_SEGMENTS)
  for distance: float in [1.0,0.99]:
   _append_vertex(buffers,Vector3(cos(angle)*distance,0.0,sin(angle)*distance),Vector2.ZERO,Vector2.ZERO,Color.WHITE)
 _strip_indices(buffers,0,PREVIEW_SEGMENTS+1)
 return _surface(buffers)

func geometry_contract() -> Dictionary:
 return {"surfaces":1,"vertices":604,"triangles":584,"mountain_sheets":3,"local_washes":3,"connected_foothills":2,"connecting_mist_strips":2,"fixed_range_edges":1,"edge_brushes":6,"snow_ribbons":4,"opening_strokes":1,"maximum_height_metres":1.82,"preview_vertices":194,"preview_triangles":192}

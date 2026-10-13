extends RefCounted
## Closed peak/body disks clipped to the original fixed disk. Every distance
## uses scalar float64; Vector3 is only the engine's incoming stored position.
const DOUBLE_EPSILON := 2.220446049250313e-16

static func point_in_circle(point: Vector3, center: Vector3, radius: float) -> bool:
 var dx: float = float(point.x)-float(center.x)
 var dz: float = float(point.z)-float(center.z)
 return dx*dx+dz*dz <= radius*radius

static func _in_all(x: float, z: float, disks: Array, constructed: bool) -> bool:
 for disk: Dictionary in disks:
  var dx: float = x-float(disk.x)
  var dz: float = z-float(disk.z)
  var radius: float = float(disk.radius)
  # Only analytically constructed circle intersections get roundoff allowance.
  # <=64 binary64 eps times squared operand scale bounds the short subtract,
  # multiply, sqrt and intersection reconstruction chain conservatively here.
  # Input points and pairwise exterior rejection NEVER use this allowance.
  var allowance: float = 0.0
  if constructed:
   var scale: float = absf(x)+absf(z)+absf(float(disk.x))+absf(float(disk.z))+radius
   allowance = 64.0*DOUBLE_EPSILON*scale*scale
  if dx*dx+dz*dz > radius*radius+allowance: return false
 return true

static func clipped_body_overlap(domain: Vector3, domain_radius: float, peak: Vector3, peak_radius: float, body: Vector3, body_radius: float) -> bool:
 # Local scalar coordinates avoid Vector2/Vector3 intermediate rounding and
 # avoid cancellation against a large absolute world origin after this point.
 var disks: Array = [
  {"x":0.0,"z":0.0,"radius":domain_radius},
  {"x":float(peak.x)-float(domain.x),"z":float(peak.z)-float(domain.z),"radius":peak_radius},
  {"x":float(body.x)-float(domain.x),"z":float(body.z)-float(domain.z),"radius":body_radius}]
 for i: int in range(3):
  for j: int in range(i+1,3):
   var dx: float = float(disks[j].x)-float(disks[i].x)
   var dz: float = float(disks[j].z)-float(disks[i].z)
   var sum_radius: float = float(disks[i].radius)+float(disks[j].radius)
   if dx*dx+dz*dz > sum_radius*sum_radius: return false
 for disk: Dictionary in disks:
  if _in_all(float(disk.x),float(disk.z),disks,false): return true
 # A nonempty intersection either contains a disk center or a pair-boundary
 # vertex contained by the third disk. Pairwise overlap alone is insufficient.
 for i: int in range(3):
  for j: int in range(i+1,3):
   var dx: float = float(disks[j].x)-float(disks[i].x)
   var dz: float = float(disks[j].z)-float(disks[i].z)
   var squared: float = dx*dx+dz*dz
   var a_radius: float = float(disks[i].radius)
   var b_radius: float = float(disks[j].radius)
   if squared == 0.0 or squared < (a_radius-b_radius)*(a_radius-b_radius): continue
   var distance: float = sqrt(squared)
   var along: float = (a_radius*a_radius-b_radius*b_radius+squared)/(2.0*distance)
   var height_squared: float = a_radius*a_radius-along*along
   var residue_bound: float = 64.0*DOUBLE_EPSILON*(a_radius*a_radius+along*along)
   if height_squared < -residue_bound: continue
   var axis_x: float = dx/distance
   var axis_z: float = dz/distance
   var base_x: float = float(disks[i].x)+axis_x*along
   var base_z: float = float(disks[i].z)+axis_z*along
   var height: float = sqrt(maxf(0.0,height_squared))
   if _in_all(base_x-axis_z*height,base_z+axis_x*height,disks,true) or _in_all(base_x+axis_z*height,base_z-axis_x*height,disks,true): return true
 return false

extends RefCounted
## Presentation geometry only. The bounds enclose the authored stone body,
## not the plume or river. This never queries or changes gameplay collisions.
const STONE_BOUNDS := AABB(Vector3(-0.78,0.0,-0.78),Vector3(1.56,1.12,1.63))
static func blocks_actor(camera_position: Vector3, beacon_transform: Transform3D, actor_position: Vector3, radius: float) -> bool:
 if not camera_position.is_finite() or not actor_position.is_finite() or not is_finite(radius) or radius < 0.0: return false
 if absf(beacon_transform.basis.determinant()) < 0.000001: return false
 var inverse: Transform3D = beacon_transform.affine_inverse()
 var origin: Vector3 = inverse * camera_position
 var spread: float = radius * 0.65
 var offsets := [Vector3(0,.06,0),Vector3(0,.45,0),Vector3(0,.9,0),Vector3(spread,.06,0),Vector3(-spread,.06,0),Vector3(0,.06,spread),Vector3(0,.06,-spread)]
 for offset: Vector3 in offsets:
  var target: Vector3 = inverse * (actor_position + offset)
  if STONE_BOUNDS.intersects_segment(origin,target) != null: return true
 return false

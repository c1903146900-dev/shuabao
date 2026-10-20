extends SceneTree
## Root-operated, one-shot offline export. Never a game/runtime entrypoint.
const Head = preload("res://yan_skin_copy_20261020/head_shape.gd")
const Cloth = preload("res://yan_skin_bake_20261020/cloth_bake.gd")
const MODEL: String="res://tests/ink_q3_gesture_runtime_20261004/assets/yanguizhou_q3_gestures.glb"
const MODEL_SHA: String="a41f04eca11416a1908caa6afc681afd2d3493b1470b402cd8ac4abd8d941bc2"
const IMPORTED: String="res://.godot/imported/yanguizhou_q3_gestures.glb-7089510de41ee79cfdde12e050e53dca.scn"
const IMPORTED_SHA: String="9e9f4962c63bdee42bd804777663dc94e21c6d6f8ceba9c7fc8097a5352ee5e8"
const HEAD_SHA: String="b0c4913888099f5d5d3e5f5a497064222fca85a9a9db1c2643b4eb0b7fcc65df"
const OUTPUT: String="/workspace/scratch/73ebae91a474/recovery_20261020/skin_cloth02/generated/yan_skin_baked_20261020"
const NAMES: Array[String]=["ScholarSurface_01_ink_robe","ScholarSurface_02_moon_silk","ScholarSurface_03_mineral_lining","ScholarSurface_04_hair_and_wet_ink","ScholarSurface_05_warm_porcelain","ScholarSurface_06_old_brass","ScholarSurface_07_black_bamboo","ScholarSurface_08_inkstone","ScholarSurface_09_ink_to_moon_cloth"]
var rig: Skeleton3D
var found: Dictionary={}
var originals: Array=[]
var copies: Array=[]
var masks: Array=[]
var head_rows: Array=[]
var cloth_rows: Array=[]
var old_positions: Array=[]
var source_digest: Array=[]
var receipt: Dictionary={"ok":false,"runtime_integration":"NOT_INSTALLED","art_acceptance":"NOT_REVIEWED"}

func _initialize() -> void:
 call_deferred("_export")

func _scan(node: Node) -> void:
 if node is Skeleton3D: rig=node
 if node is MeshInstance3D and str(node.name) in NAMES: found[str(node.name)]=node
 for child: Node in node.get_children(): _scan(child)

func _digest(value: Variant) -> String:
 var hash:=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(var_to_bytes(value))
 return hash.finish().hex_encode()

func _stop(reason: String) -> void:
 receipt["reason"]=reason
 var file:=FileAccess.open(OUTPUT+"/BAKE_RECEIPT.json",FileAccess.WRITE)
 if file!=null: file.store_string(JSON.stringify(receipt,"  "));file.close()
 print("CLOTH_BAKE_RESULT "+JSON.stringify(receipt))
 quit(0 if receipt.get("ok",false) else 1)

func _export() -> void:
 if not OS.get_cmdline_user_args().has("--export-cloth02"): _stop("explicit_export_flag_missing");return
 if DirAccess.make_dir_recursive_absolute(OUTPUT)!=OK: _stop("output_directory_unavailable");return
 if FileAccess.file_exists(OUTPUT+"/BAKE_MANIFEST.json"): _stop("output_already_finalized_no_overwrite");return
 var version: Dictionary=Engine.get_version_info()
 if int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3: _stop("requires_exact_engine_4_6_3");return
 if FileAccess.get_sha256(MODEL)!=MODEL_SHA or FileAccess.get_sha256(IMPORTED)!=IMPORTED_SHA or FileAccess.get_sha256("res://yan_skin_copy_20261020/head_shape.gd")!=HEAD_SHA: _stop("fixed_input_hash_mismatch");return
 var started: int=Time.get_ticks_usec()
 var packed: PackedScene=load(MODEL) as PackedScene
 if packed==null: _stop("model_load_failed");return
 var scene: Node=packed.instantiate()
 # Do not add scene to tree; no animations, process functions or game simulation run.
 _scan(scene)
 if rig==null or found.size()!=9: scene.free();_stop("original_nine_and_rig_missing");return
 var selected_head: int=0
 var painted: int=0
 var body_candidates: int=0
 for name: String in NAMES:
  var node: MeshInstance3D=found[name]
  if not node.mesh is ArrayMesh or node.skin==null: scene.free();_stop("original_mesh_skin_missing");return
  var original: ArrayMesh=node.mesh
  var copy: ArrayMesh=original.duplicate(false) as ArrayMesh
  if copy==null or copy==original or copy.get_rid()==original.get_rid(): scene.free();_stop("copy_not_independent");return
  originals.append(original)
  source_digest.append(_digest(original.get("_surfaces")))
  var mask: Dictionary=Cloth.classify(original,node.skin,rig,masks.size())
  if not mask.get("ok",false): scene.free();_stop("classify:"+str(mask.get("reason")));return
  for bit: int in mask.paint: painted+=bit
  for bit: int in mask.body: body_candidates+=bit
  masks.append(mask)
  var shaped: Dictionary=Head.apply(copy,node.skin,rig)
  if not shaped.get("ok",false): scene.free();_stop("head:"+str(shaped.get("reason")));return
  selected_head+=int(shaped.selected_vertices)
  head_rows.append(shaped)
  old_positions.append((copy.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate())
  copies.append(copy)
 if selected_head!=2643 or painted!=6305 or body_candidates!=4449: scene.free();_stop("offline_selection_count_mismatch");return
 # Check cross-surface coincident seams using the exact prospective deformed points.
 var seam: Dictionary=_check_seams(true)
 var use_body: bool=bool(seam.ok)
 for i in range(copies.size()):
  var baked: Dictionary=Cloth.bake(copies[i],masks[i],use_body)
  if not baked.get("ok",false): scene.free();_stop("cloth:"+str(baked.get("reason")));return
  cloth_rows.append(baked)
 var actual_seams: Dictionary=_check_seams(false)
 if not actual_seams.ok: scene.free();_stop("actual_baked_seam_check_failed");return
 var files: Array=[]
 var vertices: int=0
 var lods: int=0
 for i in range(copies.size()):
  var original: ArrayMesh=originals[i]
  var copy: ArrayMesh=copies[i]
  if _digest(original.get("_surfaces"))!=str(source_digest[i]): scene.free();_stop("original_storage_changed");return
  var original_arrays: Array=original.surface_get_arrays(0)
  var baked_arrays: Array=copy.surface_get_arrays(0)
  for ai in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:
   if _digest(original_arrays[ai])!=_digest(baked_arrays[ai]): scene.free();_stop("final_invariant_array_changed");return
  var original_stored: Array=original.get("_surfaces")
  var baked_stored: Array=copy.get("_surfaces")
  if _digest(original_stored[0].get("lods",[]))!=_digest(baked_stored[0].get("lods",[])): scene.free();_stop("final_lod_changed");return
  vertices+=copy.surface_get_array_len(0)
  lods+=int(baked_stored[0].get("lods",[]).size()/2)
  var file_name: String="mesh_%02d.res"%i
  var path: String=OUTPUT+"/"+file_name
  if ResourceSaver.save(copy,path)!=OK: scene.free();_stop("resource_save_failed:"+file_name);return
  var reloaded: ArrayMesh=ResourceLoader.load(path,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
  if reloaded==null or _digest(reloaded.surface_get_arrays(0))!=_digest(baked_arrays): scene.free();_stop("saved_resource_roundtrip_failed");return
  var stored_reload: Array=reloaded.get("_surfaces")
  if _digest(stored_reload[0].get("lods",[]))!=_digest(baked_stored[0].get("lods",[])): scene.free();_stop("saved_resource_lod_roundtrip_failed");return
  files.append({"name":NAMES[i],"file":file_name,"sha256":FileAccess.get_sha256(path),"direct_dependencies":Array(ResourceLoader.get_dependencies(path)),"source_arrays_sha256":_digest(original_arrays),"baked_arrays_sha256":_digest(baked_arrays),"head":head_rows[i],"cloth":cloth_rows[i],"classification":masks[i].components,"source_shadow_present":original.shadow_mesh!=null,"baked_shadow_present":copy.shadow_mesh!=null})
 if vertices!=12883 or lods!=47: scene.free();_stop("final_vertex_lod_count");return
 if FileAccess.get_sha256(MODEL)!=MODEL_SHA or FileAccess.get_sha256(IMPORTED)!=IMPORTED_SHA: scene.free();_stop("source_file_changed");return
 receipt.merge({"ok":true,"schema":"offline-cloth-bake-1","source_model":MODEL,"source_glb_sha256":MODEL_SHA,"source_imported_sha256":IMPORTED_SHA,"source_head_recipe_sha256":HEAD_SHA,"head_selected":2643,"painted_vertices":painted,"body_candidate_vertices":body_candidates,"body_geometry_applied":use_body,"body_fallback_reason":"none" if use_body else "prospective_seam_check_failed","prospective_seams":seam,"actual_seams":actual_seams,"vertices":vertices,"lod_pairs":lods,"build_usec":Time.get_ticks_usec()-started,"files":files,"runtime_geometry_work_required":false,"cold_process_dependency_validation":"PENDING_REQUIRED","dependency_handoff":"Direct dependencies recorded per file; stage original GLB/imported scene/textures and palette shader, then fresh GUI process loader-only validation. Same-process reload is not dependency acceptance."},true)
 var manifest:=FileAccess.open(OUTPUT+"/BAKE_MANIFEST.json",FileAccess.WRITE)
 if manifest==null: scene.free();_stop("manifest_write_failed");return
 manifest.store_string(JSON.stringify(receipt,"  "));manifest.close()
 scene.free()
 _stop("baked_candidate_not_art_approved")

func _check_seams(prospective: bool) -> Dictionary:
 var groups: Dictionary={}
 var pairs: int=0
 var maximum: float=0.0
 var errors: int=0
 for mi in range(copies.size()):
  var old: PackedVector3Array=old_positions[mi]
  var actual: PackedVector3Array=copies[mi].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for vi in range(old.size()):
   var p: Vector3=old[vi]
   var q: Vector3=actual[vi]
   if prospective:
    q=Cloth.deformation(p).position if masks[mi].body[vi]!=0 else p
   var key: String="%d:%d:%d"%[roundi(p.x*1000000.0),roundi(p.y*1000000.0),roundi(p.z*1000000.0)]
   if not groups.has(key): groups[key]={"old":p,"new":q};continue
   var old_gap: float=p.distance_to(groups[key].old)
   var new_gap: float=q.distance_to(groups[key].new)
   pairs+=1;maximum=maxf(maximum,new_gap)
   if new_gap>maxf(0.000002,old_gap*1.3): errors+=1
 return {"ok":errors==0,"pairs":pairs,"maximum_new_gap":maximum,"violations":errors}

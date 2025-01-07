@tool
extends Node3D

@export var generate : bool = false :
	set(value):
		if seed_hashed == "random":
			seed = 0
		
		elif seed != hash(seed_hashed):
			seed = hash(seed_hashed)
		
		rng = RandomNumberGenerator.new()
		if rng != null:
			rng.seed = seed
		else:
			printerr("rng is missing somehow")
			return
		
		if hp_basenoise != null:
			hp_basenoise.seed = seed
		else:
			printerr("HP BaseNoise is Missing")
			return
		
		if hp_detailnoise != null:
			hp_detailnoise.seed = seed
		else:
			printerr("HP DetailNoise is Missing")
			return
		
		_gen_basepath()
		_gen_heightpath()
		_gen_roadmesh()

@export var seed_hashed : String = "" :
	set(value):
		seed_hashed = value
		seed = hash(seed_hashed)
		
@export var seed : int = 0 : 
	set(value):
		if value == 5381:
			return
		
		if value == 0 or value == 417623846:
			seed = randi()
		else:
			seed = value
		
		if rng != null:
			rng.seed = seed
		
		if hp_basenoise != null:
			hp_basenoise.seed = seed
		
		if hp_detailnoise != null:
			hp_detailnoise.seed = seed

var rng = RandomNumberGenerator.new()

@export var detail_interval : float = 2

@export_group("BasePath")
@export var t_gen_basepath : bool = false :
	set(value):
		_gen_basepath()

@export var bp_basepath : Path3D
@export var bp_basecurve : Curve3D
@export var bp_point_count : int = 100
@export var bp_x_range : Vector2 = Vector2(-45, 45)
@export var bp_z_range : Vector2 = Vector2(-15, -20)
@export var bp_handle_range : float = 2
@export var bp_bake_interval : float = 2.5
@export var bp_ease_end : float = 1

func _bp_ease(i : float, end : float):
	if i < end:
		return min(i, 1)/end
	else:
		return 1

func _gen_basepath():
	bp_basecurve = Curve3D.new()
	bp_basecurve.add_point(Vector3.ZERO)
	bp_basecurve.add_point(Vector3.FORWARD)
	bp_basecurve.bake_interval = bp_bake_interval

	var vec_prev : Vector3 = Vector3.ZERO
	var vec_forward : Vector3 = Vector3.ZERO
	var vec_rand : Vector3 = Vector3.ZERO
	for i in bp_point_count:
		vec_prev = bp_basecurve.get_point_position(i+1)
		vec_forward = vec_prev.direction_to(bp_basecurve.get_point_position(i))
		vec_rand = Vector3(rng.randf_range(bp_x_range.x, bp_x_range.y) * _bp_ease(i, bp_ease_end), 0, rng.randf_range(bp_z_range.x, bp_z_range.y))
		bp_basecurve.add_point(vec_prev + vec_forward + vec_rand, 
			Vector3(0, 0, 10+rng.randf_range(-bp_handle_range, bp_handle_range)), 
			Vector3(0, 0, -10+rng.randf_range(-bp_handle_range, bp_handle_range)))
	
	bp_basecurve.add_point(bp_basecurve.get_point_position(bp_point_count+1)+Vector3.FORWARD*30)
	bp_basepath.curve = bp_basecurve

@export_group("HeightPath")
@export var t_gen_heightpath : bool = false :
	set(value):
		_gen_heightpath()

@export var hp_heightpath : Path3D
@export var hp_heightcurve : Curve3D
@export var hp_basenoise : FastNoiseLite
@export var hp_bn_range : Vector2 = Vector2(0, 30)
@export var hp_detailnoise : FastNoiseLite
@export var hp_dn_range : Vector2 = Vector2(-1, 1)

func _hp_noise(pos : Vector2):
	var tmp_bn = hp_basenoise.get_noise_2d(pos.x, pos.y)
	tmp_bn = remap(tmp_bn, 0, 1, hp_bn_range.x, hp_bn_range.y)
	var tmp_dn = hp_detailnoise.get_noise_2d(pos.x, pos.y)
	tmp_dn = remap(tmp_dn, 0, 1, hp_dn_range.x, hp_dn_range.y)
	return tmp_bn + tmp_dn

func _gen_heightpath():
	hp_heightcurve = Curve3D.new()
	hp_heightcurve.bake_interval = bp_bake_interval
	var vec_current : Vector3 = Vector3.ZERO
	for i in range(0, bp_basecurve.get_baked_length(), bp_bake_interval):
		vec_current = bp_basecurve.sample_baked(i)
		vec_current.y = _hp_noise(Vector2(vec_current.x, vec_current.y))
		hp_heightcurve.add_point(vec_current)

	hp_heightpath.curve = hp_heightcurve

@export_group("RoadMesh")
@export var t_gen_roadmesh : bool = false :
	set(value):
		_gen_roadmesh()

@export var rm_meshinstance : MeshInstance3D
@export var rm_mesh : Mesh
@export var rm_road_width : float = 5
@export var rm_uv_repeat : float = 1
@export var rm_uv_ratio : float = 0

func _rm_angle_to(from : Vector3, to : Vector3): # written by a deranged inumerate
	#return Vector3.FORWARD.angle_to(from.direction_to(to).normalized())
	#return from.direction_to(to)
	return -Vector2.DOWN.angle_to(Vector2(from.x, from.z).direction_to(Vector2(to.x, to.z)))
	#return Vector2(from.x, from.z).angle_to_point(Vector2(to.x, to.z))
	
func _rm_winding_order(i):
	if fmod(i+2, 2) == 0:
		return [0, 1, 2]
	else:
		return [2, 1, 0]

func _rm_xz_distance_to(from : Vector3, to : Vector3):
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _gen_roadmesh():
	var rm_vertices = PackedVector3Array()
	var rm_uvs = PackedFloat32Array([0])
	var road_angle : float = 0
	var vec_current : Vector3 = Vector3.ZERO
	var vec_next : Vector3 = Vector3.ZERO
	var vec_pos : Vector3 = Vector3.ZERO
	var uv_base : float = 0
	var uv_current : float = 0
	
	rm_uv_ratio = hp_heightcurve.get_baked_length() / rm_road_width
	
	for i in hp_heightcurve.point_count:
		if i == hp_heightcurve.point_count-1:
			break
			
		vec_current = hp_heightcurve.get_point_position(i)
		vec_next = hp_heightcurve.get_point_position(i+1)
		
		uv_base = i/float(hp_heightcurve.point_count)
		uv_current = (uv_base*rm_uv_ratio)/rm_uv_repeat
		
		road_angle = _rm_angle_to(vec_current, vec_next)
		
		vec_pos = vec_current + Vector3(-rm_road_width/2, 0, 0).rotated(Vector3.UP, road_angle)
		rm_vertices.append(vec_pos)
		rm_uvs.append(uv_current)
		
		vec_pos = vec_current + Vector3(rm_road_width/2, 0, 0).rotated(Vector3.UP, road_angle)
		rm_vertices.append(vec_pos)
		rm_uvs.append(uv_current)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in rm_vertices.size():
		for i in _rm_winding_order(e):
			if e+i > rm_vertices.size()-1:
				continue
			
			var v_even = fmod(e+i, 2) == 0
		
			st.set_uv(Vector2(int(v_even), rm_uvs[e+i]))
			
			st.add_vertex(rm_vertices[e+i])
			
	st.index()
	st.generate_normals()
	st.generate_tangents()
	rm_mesh = st.commit()
	rm_meshinstance.mesh = rm_mesh

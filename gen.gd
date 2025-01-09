@tool
extends Node3D

var p_times : Dictionary

func _p_start(a : String):
	p_times[a] = Vector3(Time.get_ticks_msec(), 0, 0)

func _p_end(a : String):
	p_times[a].y = Time.get_ticks_msec()
	p_times[a].z = p_times[a].y-p_times[a].x
	print("finished {0} in {1}ms / {2}s".format([a, p_times[a].z, p_times[a].z/1000.0]))

@export var generate : bool = false :
	set(value):
		p_times = {}
		_p_start("generating")
		if !_gen_checks():
			return
		
		_p_start("basepath")
		_gen_basepath()
		_p_end("basepath")
		_p_start("roadmesh")
		_gen_roadmesh()
		_p_end("roadmesh")
		_p_end("generating")

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
		
		if basenoise != null:
			basenoise.seed = seed
		
		if detailnoise != null:
			detailnoise.seed = seed

var rng = RandomNumberGenerator.new()

func _gen_checks():
	if seed_hashed == "random":
		seed = 0
		
	elif seed != hash(seed_hashed):
		seed = hash(seed_hashed)
		
	rng = RandomNumberGenerator.new()
	if rng != null:
		rng.seed = seed
	else:
		printerr("rng is missing somehow")
		return false
		
	if basenoise != null:
		basenoise.seed = seed
	else:
		printerr("BaseNoise is Missing")
		return false
		
	if detailnoise != null:
		detailnoise.seed = seed
	else:
		printerr("DetailNoise is Missing")
		return false
		
	if worldnoise != null:
		worldnoise.seed = seed
	else:
		printerr("WorldNoise is Missing")
		return false
		
	return true
	
func _gen_ease(i : float, end : float, max : float):
	if i < end:
		return i/end
	elif i > max-end:
		return (max-i)/end
	else:
		return 1

func _gen_hmnoise(pos : Vector2):
	var tmp_bn = basenoise.get_noise_2d(pos.x, pos.y)
	tmp_bn = remap(tmp_bn, -1, 1, hm_bn_range.x, hm_bn_range.y)
	var tmp_dn = detailnoise.get_noise_2d(pos.x, pos.y)
	tmp_dn = remap(tmp_dn, -1, 1, hm_dn_range.x, hm_dn_range.y)
	var tmp_wn = worldnoise.get_noise_2d(pos.x, pos.y)
	tmp_wn = remap(tmp_wn, -1, 1, hm_wn_range.x, hm_wn_range.y)
	return tmp_bn + tmp_dn + tmp_wn



@export_group("General")
@export var detail_interval : float = 2
@export var basenoise : FastNoiseLite
@export var detailnoise : FastNoiseLite
@export var worldnoise : FastNoiseLite
@export var hm_bn_range : Vector2 = Vector2(-15, 15)
@export var hm_dn_range : Vector2 = Vector2(-1, 1)
@export var hm_wn_range : Vector2 = Vector2(-50, 50)
@export var hm_ease_end : float = 10

@export_group("BasePath")
@export var t_gen_basepath : bool = false :
	set(value):
		if !_gen_checks():
			return
		_gen_basepath()

@export var bp_basepath : Path3D
@export var bp_basecurve : Curve3D
@export var bp_point_count : int = 100
@export var bp_x_range : Vector2 = Vector2(-45, 45)
@export var bp_z_range : Vector2 = Vector2(-15, -20)
@export var bp_handle_range : float = 2
@export var bp_ease_end : float = 1

func _gen_basepath():
	bp_basecurve = Curve3D.new()
	bp_basepath.curve = bp_basecurve
	bp_basecurve.add_point(Vector3.BACK*10)
	bp_basecurve.add_point(Vector3.FORWARD)
	bp_basecurve.bake_interval = detail_interval

	var vec_prev : Vector3 = Vector3.ZERO
	var vec_forward : Vector3 = Vector3.ZERO
	var vec_rand : Vector3 = Vector3.ZERO
	for i in bp_point_count:
		vec_prev = bp_basecurve.get_point_position(i+1)
		vec_forward = vec_prev.direction_to(bp_basecurve.get_point_position(i))
		vec_rand = Vector3(rng.randf_range(bp_x_range.x, bp_x_range.y) * _gen_ease(i, bp_ease_end, bp_point_count), 0, rng.randf_range(bp_z_range.x, bp_z_range.y))
		bp_basecurve.add_point(vec_prev + vec_forward + vec_rand, 
			Vector3(0, 0, 10+rng.randf_range(-bp_handle_range, bp_handle_range)), 
			Vector3(0, 0, -10+rng.randf_range(-bp_handle_range, bp_handle_range)))
	
	bp_basecurve.add_point(bp_basecurve.get_point_position(bp_point_count+1)+Vector3.FORWARD*30)

@export_group("RoadMesh")
@export var t_gen_roadmesh : bool = false :
	set(value):
		if !_gen_checks():
			return
		_gen_roadmesh()

@export var rm_meshinstance : MeshInstance3D
@export var rm_road_width : float = 5
@export var rm_uv_repeat : int = 2
@export var rm_verts = PackedVector3Array()
@export var rm_uvs = PackedFloat32Array()
@export var rm_uv_ratio : float = 0
@export var rm_mesh : Mesh

func _rm_angle_to(from : Vector3, to : Vector3): # no longer written by a deranged inumerate, just a regular one
	#return Vector2(from.x, from.z).angle_to_point(Vector2(to.x, to.z))
	return Vector2(from.x, from.z).direction_to(Vector2(to.x, to.z))

func _rm_winding_order(i):
	if fmod(i+2, 2) == 0:
		return [0, 1, 2]
	else:
		return [2, 1, 0]

func _gen_roadmesh():
	var rm_verts = PackedVector3Array()
	var rm_uvs = PackedFloat32Array()
	
	var uv_base
	var uv_current
	 
	var vec_current : Vector3
	var vec_next : Vector3
	var vec_left : Vector2
	var vec3_left : Vector3
	var vec_right : Vector2
	var vec3_right : Vector3

	rm_uv_ratio = bp_basecurve.get_baked_length() / rm_road_width

	var point_count = bp_basecurve.get_baked_length()/detail_interval
	for p in point_count:
		if p+2 > point_count:
			break
		
		vec_current = bp_basecurve.sample_baked(p*detail_interval)
		vec_next = bp_basecurve.sample_baked((p+1)*detail_interval)
		vec_left = _rm_angle_to(vec_current, vec_next).rotated(-90)*rm_road_width/2
		vec3_left = vec_current + Vector3(vec_right.x, 0, vec_right.y)
		vec3_left.y = _gen_hmnoise(Vector2(vec3_left.x, vec3_left.z))*_gen_ease(p, hm_ease_end, point_count)
		vec_right = _rm_angle_to(vec_current, vec_next).rotated(90)*rm_road_width/2
		vec3_right = vec_current + Vector3(vec_left.x, 0, vec_left.y)
		vec3_right.y = _gen_hmnoise(Vector2(vec3_right.x, vec3_right.z))*_gen_ease(p, hm_ease_end, point_count)
		
		rm_verts.append(vec3_left)
		rm_verts.append(vec3_right)

		uv_base = p/float(point_count)
		uv_current = wrapf((uv_base*rm_uv_ratio)/rm_uv_repeat, 0, 1)
		
		rm_uvs.append(uv_current) # still not normalized. lol

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in rm_verts.size():
		for i in _rm_winding_order(e):
			if e+i > rm_verts.size()-1:
				continue
			
			var v_even = fmod(e+i, 2) == 0
			st.set_uv(Vector2(int(v_even), rm_uvs[(e+i)/2]))
			st.add_vertex(rm_verts[e+i])
			
	st.index()
	st.generate_normals()
	st.generate_tangents()
	rm_mesh = st.commit()
	rm_meshinstance.mesh = rm_mesh

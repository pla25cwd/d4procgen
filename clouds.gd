extends MeshInstance3D

var noise : FastNoiseLite
var pos_offset : float = 0

func _ready() -> void:
	noise = get_material_override().get_shader_parameter("i_noise").get_noise()
	noise.seed = randi()
	
func _physics_process(delta: float) -> void:
	pos_offset += delta
	noise.offset.x = global_position.x*5 - pos_offset
	noise.offset.y = global_position.z*5 + pos_offset
	noise.offset.z += delta

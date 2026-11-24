extends Area3D
## A reachable interaction volume around a school desk or a piece of evidence.
var glyph := Label3D.new()
var shown_model: Node3D

func setup(entry:Dictionary, extra:bool) -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	set_meta("interaction_id",str(entry.id))
	set_meta("interaction_label",str(entry.label))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.12,1.48,1.0)
	collision.shape = shape
	collision.position.y = 0.86
	add_child(collision)
	var base := MeshInstance3D.new()
	var cabinet := BoxMesh.new()
	cabinet.size = Vector3(0.75,0.72,0.50)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#585446")
	finish.roughness = 0.88
	cabinet.material = finish
	base.mesh = cabinet
	base.position.y = 0.36
	add_child(base)
	var model_path := "res://assets/items/models/%s.glb" % entry.get("item","mystery_note")
	if ResourceLoader.exists(model_path):
		shown_model = load(model_path).instantiate()
		add_child(shown_model)
		shown_model.position.y = 0.77
	glyph.text = "◇" if extra else "◆"
	glyph.modulate = Color("#b5c3b8") if extra else Color("#e8c38b")
	glyph.outline_size = 4
	glyph.font_size = 30
	glyph.pixel_size = .0035
	glyph.position.y = 1.47
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(glyph)

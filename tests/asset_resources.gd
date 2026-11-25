extends SceneTree

var checked := 0
var failures := 0
var scenes := 0

func _initialize() -> void:
	var pending = ["res://assets", "res://scenes"]
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if FileAccess.file_exists(path.path_join(".gdignore")):
			continue
		for child in DirAccess.get_directories_at(path):
			pending.append(path.path_join(child))
		for name in DirAccess.get_files_at(path):
			if name.get_extension() not in ["glb","tres","tscn","svg","png","webp","jpg","ogg","wav","ttf"]:
				continue
			var filename := path.path_join(name)
			var res = ResourceLoader.load(filename)
			checked += 1
			if not res:
				failures += 1
				printerr("Resource tidak bisa dimuat: " + filename)
			elif res is PackedScene:
				var instance:Node = res.instantiate()
				scenes += 1
				if instance:
					instance.free()
				else:
					failures += 1
					printerr("Gagal membuat instance: " + filename)
	if checked < 400 or scenes < 100:
		failures += 1
		printerr("Jumlah sumber terlalu rendah; jalankan dari proyek sumber setelah impor editor.")
	print("%d resources loaded; %d scenes instantiated; %d failures." % [checked, scenes, failures])
	quit(1 if failures > 0 else 0)

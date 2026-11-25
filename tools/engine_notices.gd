extends SceneTree
## Extract attribution from the same Godot binary used to build the release.
func _initialize() -> void:
	var file = FileAccess.open("res://docs/licenses/GODOT-NOTICES.txt", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_line("Godot Engine " + Engine.get_version_info().string)
	file.store_line(Engine.get_license_text())
	for component in Engine.get_copyright_info():
		file.store_line("\n" + component.name)
		for part in component.parts:
			file.store_line("Files: " + ", ".join(part.files))
			file.store_line("License: " + part.license)
			for notice in part.copyright:
				file.store_line(notice)
	var licenses := Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for key in names:
		file.store_line("\n" + key + "\n" + licenses[key])
	file.close()
	quit()

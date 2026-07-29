extends Node
# Autoload, last in the fixed order (CODING.md §3). Reads GameState; triggers
# AudioDirector mood/SFX on transitions. All scene transitions go through here - no scene
# loads another directly.

signal scene_changed(scene_path: String)


func go_to(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err == OK:
		# Layered under whatever SFX the triggering button itself already played
		# (DM-010's audio map) - every scene swap gets this, not just S1-S3's, so a
		# future screen never has to remember to wire it in itself.
		AudioDirector.play_sfx(&"ui_transition")
		scene_changed.emit(scene_path)

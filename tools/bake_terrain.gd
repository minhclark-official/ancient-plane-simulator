extends SceneTree
## Bakes the terrain height + colour grid into res://assets/data/terrain.bin
## Run:  godot --headless --path . --script res://tools/bake_terrain.gd


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	WorldData.compute_grid()
	WorldData.save_grid()
	print("terrain baked in ", Time.get_ticks_msec() - t0, " ms: ", WorldData.H.size(), " samples")
	quit()

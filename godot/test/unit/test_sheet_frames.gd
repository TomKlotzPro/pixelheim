extends GutTest
## The shared strip loaders must slice sheets into the expected frame counts
## and normalize Pixel Crawler's mixed canvas sizes to 48x48.


func test_hero_slice_sheet_has_eight_full_frames() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, "slice", "res://assets/crawler/hero_slice_down.png", 20.0, false, 64)
	assert_eq(frames.get_frame_count("slice"), 8)
	assert_eq(frames.get_frame_texture("slice", 0).get_width(), 64)


func test_mob_idle_normalizes_32px_frames_to_48() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_normalized_strip(frames, "idle", "res://assets/crawler/orc_idle.png", 4.0, true)
	assert_eq(frames.get_frame_count("idle"), 4)
	assert_eq(frames.get_frame_texture("idle", 0).get_width(), 48)
	assert_eq(frames.get_frame_texture("idle", 0).get_height(), 48)


func test_mob_run_crops_64px_frames_to_48() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_normalized_strip(frames, "run", "res://assets/crawler/orc_run.png", 10.0, true)
	assert_eq(frames.get_frame_count("run"), 6)
	assert_eq(frames.get_frame_texture("run", 0).get_width(), 48)


func test_generated_16px_strips_slice_by_default_size() -> void:
	var frames := SpriteFrames.new()
	SheetFrames.add_strip(frames, "walk", "res://assets/sprites/hero_warrior_walk.png", 6.0, true)
	assert_eq(frames.get_frame_count("walk"), 4)
	assert_eq(frames.get_frame_texture("walk", 0).get_width(), 16)

extends GutTest


func test_bus_graph_is_master_bgm_sfx_ui() -> void:
	assert_eq(AudioServer.bus_count, 4)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	var bus_names: Array[String] = []
	for i in AudioServer.bus_count:
		bus_names.append(AudioServer.get_bus_name(i))
	assert_true(bus_names.has("BGM"))
	assert_true(bus_names.has("SFX"))
	assert_true(bus_names.has("UI"))


func test_bgm_sfx_ui_all_send_to_master() -> void:
	for bus_name in ["BGM", "SFX", "UI"]:
		var idx := AudioServer.get_bus_index(bus_name)
		assert_eq(AudioServer.get_bus_send(idx), "Master")


func test_all_four_required_moods_exist() -> void:
	for mood in [&"barangay_calm", &"investigating", &"tension", &"revelation"]:
		assert_true(AudioDirector.MOOD_CLIPS.has(mood), "missing required mood: %s" % mood)


func test_set_mood_starts_bgm_playback() -> void:
	AudioDirector.set_mood(&"barangay_calm")
	await get_tree().create_timer(0.2).timeout
	assert_true(AudioDirector._bgm_player.playing)


func test_set_mood_transitions_without_stopping_playback() -> void:
	AudioDirector.set_mood(&"barangay_calm")
	await get_tree().create_timer(0.2).timeout
	AudioDirector.set_mood(&"investigating")
	await get_tree().create_timer(0.2).timeout
	# Still playing through the crossfade, never a hard stop (DM-011 acceptance: "not an
	# abrupt cut").
	assert_true(AudioDirector._bgm_player.playing)


func test_set_mood_same_mood_twice_is_a_no_op() -> void:
	AudioDirector.set_mood(&"barangay_calm")
	await get_tree().create_timer(0.2).timeout
	watch_signals(AudioDirector)
	AudioDirector.set_mood(&"barangay_calm")
	assert_signal_not_emitted(AudioDirector, "mood_changed")


func test_set_mood_unknown_name_logs_instead_of_crashing() -> void:
	AudioDirector.set_mood(&"nonexistent_mood")
	assert_push_error("unknown mood")


func test_play_sfx_unknown_id_logs_instead_of_crashing() -> void:
	AudioDirector.play_sfx(&"nonexistent_sfx")
	assert_push_error("unknown sfx id")


func test_play_sfx_routes_to_sfx_bus_pool() -> void:
	AudioDirector.play_sfx(&"trust_down")
	var any_playing := false
	for p in AudioDirector._sfx_players:
		if p.playing:
			any_playing = true
	assert_true(any_playing)


func test_play_sfx_routes_ui_ids_to_ui_bus_pool() -> void:
	AudioDirector.play_sfx(&"ui_tap")
	var any_playing := false
	for p in AudioDirector._ui_players:
		if p.playing:
			any_playing = true
	assert_true(any_playing)


func test_set_and_get_bus_volume_round_trips() -> void:
	AudioDirector.set_bus_volume(&"SFX", 0.5)
	assert_almost_eq(AudioDirector.get_bus_volume(&"SFX"), 0.5, 0.01)
	AudioDirector.set_bus_volume(&"SFX", 1.0)


func test_set_bus_volume_persists_through_save_manager() -> void:
	AudioDirector.set_bus_volume(&"UI", 0.4)
	var settings := SaveManager.load_settings()
	assert_almost_eq(float(settings.get("ui_volume", -1.0)), 0.4, 0.01)
	AudioDirector.set_bus_volume(&"UI", 1.0)


## DM-051: pausing the SceneTree does not pause audio on its own (playback is
## server-driven) - set_paused() is what DM-051's overlay mechanism relies on to
## actually freeze the soundscape together with the frozen scene.
func test_set_paused_true_pauses_the_bgm_player() -> void:
	AudioDirector.set_mood(&"barangay_calm")
	await get_tree().create_timer(0.2).timeout
	AudioDirector.set_paused(true)
	assert_true(AudioDirector._bgm_player.stream_paused)
	AudioDirector.set_paused(false)


func test_set_paused_false_resumes_the_bgm_player() -> void:
	AudioDirector.set_mood(&"barangay_calm")
	await get_tree().create_timer(0.2).timeout
	AudioDirector.set_paused(true)
	AudioDirector.set_paused(false)
	assert_false(AudioDirector._bgm_player.stream_paused)


func test_set_paused_does_not_block_a_fresh_sfx_play_afterwards() -> void:
	# A player that was stream_paused while idle must still play normally once picked
	# for a new play() call (verified against the real engine before relying on it) -
	# otherwise every UI tap inside a paused pause-menu would go silent.
	AudioDirector.set_paused(true)
	AudioDirector.set_paused(false)
	AudioDirector.play_sfx(&"ui_tap")
	var any_playing := false
	for p in AudioDirector._ui_players:
		if p.playing:
			any_playing = true
	assert_true(any_playing)

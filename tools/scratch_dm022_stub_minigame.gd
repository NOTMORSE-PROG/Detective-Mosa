extends MiniGame
# DM-022 - scratch, NOT a real mini-game (that's DM-023+). Draws a few coloured rects as
# stand-in puzzle content purely so MiniGameHost's own layout can be rendered and judged
# for real, since MiniGame.gd itself has zero visual content on its own.


func _draw() -> void:
	draw_rect(Rect2(40, 40, 200, 150), Color(0.6, 0.5, 0.4, 1.0))
	draw_rect(Rect2(280, 40, 200, 150), Color(0.5, 0.6, 0.4, 1.0))
	draw_rect(Rect2(520, 40, 200, 150), Color(0.4, 0.5, 0.6, 1.0))

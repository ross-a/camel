package screens;

import "../../ext/raylib"

init_gameplay_screen :: proc(s : ^Screen) {
  s.frames_counter = 0;
  s.finish_screen = 0;
}

update_gameplay_screen :: proc(s : ^Screen, fx : raylib.Sound) {
	using raylib;
  // Press enter or tap to change to ENDING screen
  if s.accept_input && (is_key_pressed(KEY_ENTER) || is_gesture_detected(GESTURE_TAP))
  {
    s.finish_screen = 1;
    play_sound(fx);
  }
}

draw_gameplay_screen :: proc(s : ^Screen, font : raylib.Font) {
	using raylib;
  draw_rectangle(0, 0, get_screen_width(), get_screen_height(), PURPLE);
  draw_text_ex(font, "GAMEPLAY SCREEN", (Vector2){ 20, 10 }, cast(f32)font.base_size*3, 4, MAROON);
	draw_text("PRESS ENTER or TAP to JUMP to ENDING SCREEN", 130, 220, 20, MAROON);
}

unload_gameplay_screen :: proc(s : ^Screen) {
  // TODO: Unload GAMEPLAY screen variables here!
}

// Gameplay Screen should finish?
finish_gameplay_screen :: proc(s : ^Screen) -> i32 {
  return s.finish_screen;
}

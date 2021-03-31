package screens;

import "../../ext/raylib"

init_title_screen :: proc(s : ^Screen) {
  s.frames_counter = 0;
  s.finish_screen = 0;
}

update_title_screen :: proc(s : ^Screen, fx : raylib.Sound) {
	using raylib;
  // Press enter or tap to change to GAMEPLAY screen
  if s.accept_input && (is_key_pressed(KEY_ENTER) || is_gesture_detected(GESTURE_TAP))
  {
    s.finish_screen = 2;   // GAMEPLAY
    play_sound(fx);
  }
}

draw_title_screen :: proc(s : ^Screen, font : raylib.Font) {
	using raylib;
  draw_rectangle(0, 0, get_screen_width(), get_screen_height(), GREEN);
  draw_text_ex(font, "TITLE SCREEN", (Vector2){ 20, 10 }, cast(f32)font.base_size*3, 4, DARKGREEN);
  draw_text("PRESS ENTER or TAP to JUMP to GAMEPLAY SCREEN", 120, 220, 20, DARKGREEN);
}

unload_title_screen :: proc(s : ^Screen) {
  // TODO: Unload TITLE screen variables here!
}

finish_title_screen :: proc (s : ^Screen) -> i32 {
  return s.finish_screen;
}

package screens;

import "../../ext/raylib"

init_ending_screen :: proc (s : ^Screen) {
  s.frames_counter = 0;
  s.finish_screen = 0;
}

update_ending_screen :: proc (s : ^Screen, fx : raylib.Sound) {
	using raylib;
  if s.accept_input && (is_key_pressed(KEY_ENTER) || is_gesture_detected(GESTURE_TAP))
  {
    s.finish_screen = 1;
    play_sound(fx);
  }
}

draw_ending_screen :: proc (s : ^Screen, font : raylib.Font) {
	using raylib;
  draw_rectangle(0, 0, get_screen_width(), get_screen_height(), BLUE);
  draw_text_ex(font, "ENDING SCREEN", (Vector2){ 20, 10 }, cast(f32)font.base_size*3, 4, DARKBLUE);
  draw_text("PRESS ENTER or TAP to RETURN to TITLE SCREEN", 120, 220, 20, DARKBLUE);
}

unload_ending_screen :: proc (s : ^Screen) {
  // TODO: Unload ENDING screen variables here!
}

finish_ending_screen :: proc (s : ^Screen) -> i32
{
  return s.finish_screen;
}

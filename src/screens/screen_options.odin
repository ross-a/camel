package screens;

init_options_screen :: proc (s : ^Screen) {
  s.frames_counter = 0;
  s.finish_screen = 0;
}

update_options_screen :: proc (s : ^Screen) {
  // TODO: Update OPTIONS screen variables here!
}

draw_options_screen :: proc (s : ^Screen) {
  // TODO: Draw OPTIONS screen here!
}

unload_options_screen :: proc (s : ^Screen) {
  // TODO: Unload OPTIONS screen variables here!
}

finish_options_screen :: proc (s : ^Screen) -> i32 {
  return s.finish_screen;
}

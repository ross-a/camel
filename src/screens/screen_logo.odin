package screens;

import "../../ext/raylib"
import "core:strings"

LOGO_SIZE :: 50;

init_logo_screen :: proc(s : ^Screen) {
	using raylib;

  // Initialize LOGO screen variables here!
  s.finish_screen = 0;
  s.frames_counter = 0;
  s.letters_count = 0;
	s.accept_input = true;

  s.logo_position_x = get_screen_width() - LOGO_SIZE - 16;
  s.logo_position_y = get_screen_height() - LOGO_SIZE - 16;

  for i in 0..<8 {
		s.raylib_text[i] = 0;
	}

  s.state = 0;
  s.alpha = 1.0;

	// Load Odin logo and camel animation texture
	s.odin_logo_anim = load_texture("assets/odin_logo_anim.png");
	s.camel_anim = load_texture("assets/camel_walk_anim.png");
}

update_logo_screen :: proc(s : ^Screen) {
  if (s.state == 0)                 // State 0: Small box blinking
  {
    s.frames_counter += 1;
		s.odin_logo_frame_cnt = 0;
		s.camel_frame_cnt = 0;

    if (s.frames_counter == 80)
    {
      s.state = 1;
      s.frames_counter = 0;					// Reset counter... will be used later...
    }
  }
  else if (s.state == 1)            // State 1: Top and left bars growing
  {
    s.top_side_rec_width += LOGO_SIZE/32;
    s.left_side_rec_height += LOGO_SIZE/32;

    if (s.top_side_rec_width >= LOGO_SIZE) do s.state = 2;
  }
  else if (s.state == 2)            // State 2: Bottom and right bars growing
  {
    s.bottom_side_rec_width += LOGO_SIZE/32;
    s.right_side_rec_height += LOGO_SIZE/32;

    if (s.bottom_side_rec_width >= LOGO_SIZE) do s.state = 3;
  }
  else if (s.state == 3)            // State 3: Letters appearing (one by one)
  {
    s.frames_counter += 1;

    if (s.frames_counter % 10 == 0) // Every 12 frames, one more letter!
    {
      s.letters_count += 1;
      s.frames_counter = 0;
    }

    switch s.letters_count
    {
      case 1: s.raylib_text[0] = 'r';
      case 2: s.raylib_text[1] = 'a';
      case 3: s.raylib_text[2] = 'y';
      case 4: s.raylib_text[3] = 'l';
      case 5: s.raylib_text[4] = 'i';
      case 6: s.raylib_text[5] = 'b';
    }

    // When all letters have appeared...
    if (s.letters_count >= 10)
    {
      s.state = 4;
      s.frames_counter = 0;
    }
  }
  else if (s.state == 4)
  {
    s.frames_counter += 1;

    if (s.frames_counter > 200)
    {
      s.alpha -= 0.02;

      if (s.alpha <= 0.0)
      {
        s.alpha = 0.0;
        s.finish_screen = 1;
      }
    }
  }

	if (s.state > 0) {
		s.odin_logo_frame_cnt += 1;
		if s.odin_logo_frame_cnt > 98 do s.odin_logo_frame_cnt = 98;

		s.camel_frame_cnt += 1;
		if s.camel_frame_cnt > 24 do s.camel_frame_cnt = 0;
	}
}

draw_logo_screen :: proc (s : ^Screen) {
	using raylib;

	tf   : i32 = LOGO_SIZE-LOGO_SIZE/16;
	ttf  : i32 = LOGO_SIZE-LOGO_SIZE/8;
	ttf2 : i32 = ttf/2;

  if (s.state == 0)
  {
    if ((s.frames_counter/10)%2 != 0) do draw_rectangle(s.logo_position_x, s.logo_position_y, LOGO_SIZE/16, LOGO_SIZE/16, BLACK);
  }
  else if (s.state == 1)
  {
    draw_rectangle(s.logo_position_x, s.logo_position_y, s.top_side_rec_width, LOGO_SIZE/16, BLACK);
    draw_rectangle(s.logo_position_x, s.logo_position_y, LOGO_SIZE/16, s.left_side_rec_height, BLACK);
  }
  else if (s.state == 2)
  {
    draw_rectangle(s.logo_position_x, s.logo_position_y, s.top_side_rec_width, LOGO_SIZE/16, BLACK);
    draw_rectangle(s.logo_position_x, s.logo_position_y, LOGO_SIZE/16, s.left_side_rec_height, BLACK);

    draw_rectangle(s.logo_position_x + tf, s.logo_position_y, LOGO_SIZE/16, s.right_side_rec_height, BLACK);
    draw_rectangle(s.logo_position_x, s.logo_position_y + tf, s.bottom_side_rec_width, LOGO_SIZE/16, BLACK);
  }
  else if (s.state == 3)
  {
    draw_rectangle(s.logo_position_x, s.logo_position_y, s.top_side_rec_width, LOGO_SIZE/16, fade(BLACK, s.alpha));
    draw_rectangle(s.logo_position_x, s.logo_position_y + LOGO_SIZE/16, LOGO_SIZE/16, s.left_side_rec_height - LOGO_SIZE/8, fade(BLACK, s.alpha));

    draw_rectangle(s.logo_position_x + tf, s.logo_position_y + LOGO_SIZE/16, LOGO_SIZE/16, s.right_side_rec_height - LOGO_SIZE/8, fade(BLACK, s.alpha));
    draw_rectangle(s.logo_position_x, s.logo_position_y + tf, s.bottom_side_rec_width, LOGO_SIZE/16, fade(BLACK, s.alpha));

    draw_rectangle(get_screen_width()/2 - ttf2, get_screen_height()/2 - ttf2, ttf, ttf, fade(RAYWHITE, s.alpha));

		str := strings.string_from_ptr(&s.raylib_text[0], 8);
    draw_text(strings.clone_to_cstring(str), s.logo_position_x + (LOGO_SIZE/2) - (LOGO_SIZE/6), s.logo_position_y + (LOGO_SIZE/2) + (LOGO_SIZE/5), (LOGO_SIZE/5), fade(BLACK, s.alpha));
  }
  else if (s.state == 4)
  {
    draw_rectangle(s.logo_position_x, s.logo_position_y, s.top_side_rec_width, LOGO_SIZE/16, fade(BLACK, s.alpha));
    draw_rectangle(s.logo_position_x, s.logo_position_y + LOGO_SIZE/16, LOGO_SIZE/16, s.left_side_rec_height - LOGO_SIZE/8, fade(BLACK, s.alpha));

    draw_rectangle(s.logo_position_x + tf, s.logo_position_y + LOGO_SIZE/16, LOGO_SIZE/16, s.right_side_rec_height - LOGO_SIZE/8, fade(BLACK, s.alpha));
    draw_rectangle(s.logo_position_x, s.logo_position_y + tf, s.bottom_side_rec_width, LOGO_SIZE/16, fade(BLACK, s.alpha));

    draw_rectangle(get_screen_width()/2 - ttf2, get_screen_height()/2 - ttf2, ttf, ttf, fade(RAYWHITE, s.alpha));

		str := strings.string_from_ptr(&s.raylib_text[0], 8);
    draw_text(strings.clone_to_cstring(str), s.logo_position_x + (LOGO_SIZE/2) - (LOGO_SIZE/6), s.logo_position_y + (LOGO_SIZE/2) + (LOGO_SIZE/5), (LOGO_SIZE/5), fade(BLACK, s.alpha));

    //if (s.frames_counter > 20) do draw_text("powered by", s.logo_position_x - 6, s.logo_position_y - LOGO_SIZE/9 - 6, LOGO_SIZE/12, fade(DARKGRAY, s.alpha));
  }

	// Draw odin logo (animate png sprite sheet)
	if (s.state > 0) {
		andsign := "&";
		draw_text(strings.clone_to_cstring(andsign), s.logo_position_x - 20, s.logo_position_y + 20, (LOGO_SIZE/5), fade(BLACK, s.alpha));

		s.odin_logo_position = { cast(f32)s.logo_position_x - 180, cast(f32)s.logo_position_y - 25 };
		s.odin_logo_frame_rect = { 0, 0, 160, 100 };
		cnt : f32 = cast(f32)s.odin_logo_frame_cnt;
		s.odin_logo_frame_rect.x += cnt * 160;
		if s.odin_logo_frame_cnt < 40 {
			draw_texture_rec(s.odin_logo_anim, s.odin_logo_frame_rect, s.odin_logo_position, fade(BLACK, cnt/40));
		} else {
			draw_texture_rec(s.odin_logo_anim, s.odin_logo_frame_rect, s.odin_logo_position, fade(BLACK, s.alpha));
		}

		s.camel_position = { cast(f32)get_screen_width()/2 - 320, cast(f32)get_screen_height()/2 - 240 };
		s.camel_frame_rect = { 0, 0, 640, 480 };
		ccnt : f32 = cast(f32)s.camel_frame_cnt;
		s.camel_frame_rect.x += ccnt * 640;
		draw_texture_rec(s.camel_anim, s.camel_frame_rect, s.camel_position, fade(WHITE, s.alpha));
	}
}

unload_logo_screen :: proc (s : ^Screen) {
  // Unload LOGO screen variables here!
}

finish_logo_screen :: proc (s : ^Screen) -> i32 {
  return s.finish_screen;
}

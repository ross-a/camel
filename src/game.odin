package game

import "../ext/raylib"
import "../ext/raygui"
//import "core:fmt"
//import "core:mem"
//import "core:strings"
//import "core:path"

import "plugin"
import "screens"
import "console"

Game :: struct {
	current_screen		: screens.Game_Screen,
	screen            : screens.Screen,
	font							: raylib.Font,
	music							: raylib.Music,
	fx								: raylib.Sound,
	// ------------------------------
	trans_alpha				: f32,
	on_transition			: bool,
	trans_fade_out		: bool,
	trans_from_screen : screens.Game_Screen,
	trans_to_screen		: screens.Game_Screen,
	toggle_console    : bool,
}

change_to_screen :: proc(game : ^Game, screen : screens.Game_Screen)
{
	// no transition effect
	#partial switch game.current_screen {
    case screens.Game_Screen.LOGO: screens.unload_logo_screen(&game.screen);
    case screens.Game_Screen.TITLE: screens.unload_title_screen(&game.screen);
    case screens.Game_Screen.GAMEPLAY: screens.unload_gameplay_screen(&game.screen);
    case screens.Game_Screen.ENDING: screens.unload_ending_screen(&game.screen);
  }

  // Init next screen
  #partial switch screen {
    case screens.Game_Screen.LOGO: screens.init_logo_screen(&game.screen);
    case screens.Game_Screen.TITLE: screens.init_title_screen(&game.screen);
    case screens.Game_Screen.GAMEPLAY: screens.init_gameplay_screen(&game.screen);
    case screens.Game_Screen.ENDING: screens.init_ending_screen(&game.screen);
  }

  game.current_screen = screen;
}

transition_to_screen :: proc(game : ^Game, screen : screens.Game_Screen)
{
	// transition to next screen
	game.trans_alpha = 0.0;
	game.on_transition = true;
	game.trans_fade_out = false;
	game.trans_from_screen = game.current_screen;
	game.trans_to_screen = screen;
	game.toggle_console = false;
}

update_transition :: proc(game : ^Game)
{
	using game;
	// update transition effect
  if !trans_fade_out {
    trans_alpha += 0.05;

    // NOTE: Due to float internal representation, condition jumps on 1.0f instead of 1.05f
    // For that reason we compare against 1.01f, to avoid last frame loading stop
    if trans_alpha > 1.01 {
      trans_alpha = 1.0;

      // Unload current screen
      #partial switch trans_from_screen
      {
        case screens.Game_Screen.LOGO: screens.unload_logo_screen(&game.screen);
        case screens.Game_Screen.TITLE: screens.unload_title_screen(&game.screen);
        case screens.Game_Screen.OPTIONS: screens.unload_options_screen(&game.screen);
        case screens.Game_Screen.GAMEPLAY: screens.unload_gameplay_screen(&game.screen);
        case screens.Game_Screen.ENDING: screens.unload_ending_screen(&game.screen);
      }

      // Load next screen
      #partial switch (trans_to_screen)
      {
        case screens.Game_Screen.LOGO: screens.init_logo_screen(&game.screen);
        case screens.Game_Screen.TITLE: screens.init_title_screen(&game.screen);
        case screens.Game_Screen.GAMEPLAY: screens.init_gameplay_screen(&game.screen);
        case screens.Game_Screen.ENDING: screens.init_ending_screen(&game.screen);
      }

      current_screen = trans_to_screen;

      // Activate fade out effect to next loaded screen
      trans_fade_out = true;
    }
  } else {
		// Transition fade out logic
    trans_alpha -= 0.02;

    if trans_alpha < -0.01 {
      trans_alpha = 0.0;
      trans_fade_out = false;
      on_transition = false;
      trans_from_screen = screens.Game_Screen.LOGO;
      trans_to_screen = screens.Game_Screen.LOGO;
			toggle_console = false;
    }
  }
}

draw_transition :: proc(game : ^Game)
{
	// Draw transition effect (full-screen rectangle)
	using raylib;
	draw_rectangle(0, 0, get_screen_width(), get_screen_height(), fade(raylib.BLACK, game.trans_alpha));
}

update_draw_frame :: proc(game : ^Game)
{
	using game;
	using raylib;
	using screens;
	// update and draw one frame
  //----------------------------------------------------------------------------------
  update_music_stream(music);       // NOTE: Music keeps playing between screens

  if (!on_transition)
  {
    #partial switch current_screen {
      case Game_Screen.LOGO:
			{
				update_logo_screen(&screen);
				if finish_logo_screen(&screen) == 1 do transition_to_screen(game, Game_Screen.TITLE);
			}
			case Game_Screen.TITLE:
			{
				update_title_screen(&screen, fx);
				if finish_title_screen(&screen) == 1 do transition_to_screen(game, Game_Screen.OPTIONS);
				else if finish_title_screen(&screen) == 2 do	transition_to_screen(game, Game_Screen.GAMEPLAY);
			}
      case Game_Screen.OPTIONS:
			{
				update_options_screen(&screen);
        if finish_options_screen(&screen) == 1 do	transition_to_screen(game, Game_Screen.TITLE);
			}
      case Game_Screen.GAMEPLAY:
      {
        update_gameplay_screen(&screen, fx);
        if finish_gameplay_screen(&screen) == 1 do	transition_to_screen(game, Game_Screen.ENDING);
      }
      case Game_Screen.ENDING:
      {
        update_ending_screen(&screen, fx);
        if finish_ending_screen(&screen) == 1 do	transition_to_screen(game, Game_Screen.TITLE);
      }
    }
  } else {
		update_transition(game);    // Update transition (fade-in, fade-out)
	}
  //----------------------------------------------------------------------------------
  // Draw
  //----------------------------------------------------------------------------------
  begin_drawing();
  clear_background(RAYWHITE);

  #partial switch current_screen
  {
    case Game_Screen.LOGO: draw_logo_screen(&screen);
    case Game_Screen.TITLE: draw_title_screen(&screen, font);
    case Game_Screen.OPTIONS: draw_options_screen(&screen);
    case Game_Screen.GAMEPLAY: draw_gameplay_screen(&screen, font);
    case Game_Screen.ENDING: draw_ending_screen(&screen, font);
  }

  // Draw full screen rectangle in front of everything
  if on_transition do	draw_transition(game);

  if is_key_pressed(KEY_GRAVE) {
		toggle_console = !toggle_console;
		screen.accept_input = !toggle_console;
	}
	if toggle_console {
		console.update_draw_console();
	}
  //draw_fps(10, 10);

	end_drawing();
  //----------------------------------------------------------------------------------
}

// game global
//----------------------------------------------------------------------------------
game : Game;

// on_load
//----------------------------------------------------------------------------------
@(export)
on_load :: proc(set_screen_to : screens.Game_Screen) {
	using raylib;

	game.trans_alpha				= 0.0;
	game.on_transition			= false;
	game.trans_fade_out			= false;
	game.trans_from_screen	= set_screen_to;
	game.trans_to_screen		= set_screen_to;
	game.toggle_console     = false;

	// Initialization
  //---------------------------------------------------------
	icon := load_image("assets/icon.png");
	set_window_icon(icon);
	//toggle_fullscreen();

  game.font = load_font("assets/mecha.png");
	//raygui.gui_set_font(game.font);
	raygui.gui_set_font(get_font_default()); // it's a nice default

  game.music = load_music_stream("assets/ambient.ogg");
  game.fx = load_sound("assets/coin.wav");

  set_music_volume(game.music, 1.0);
  //play_music_stream(game.music);

  // Setup and Init first screen
  game.current_screen = set_screen_to;
  screens.init_logo_screen(&game.screen);
}

@(export)
on_unload :: proc() -> screens.Game_Screen {
	using raylib;

	// De-Initialization
  //--------------------------------------------------------------------------------------
  #partial switch game.current_screen {
    case screens.Game_Screen.LOGO: screens.unload_logo_screen(&game.screen);
    case screens.Game_Screen.TITLE: screens.unload_title_screen(&game.screen);
    case screens.Game_Screen.GAMEPLAY: screens.unload_gameplay_screen(&game.screen);
    case screens.Game_Screen.ENDING: screens.unload_ending_screen(&game.screen);
  }

	unload_font(game.font);
	unload_music_stream(game.music);
	unload_sound(game.fx);

	return game.current_screen;
}

@(export)
update_and_draw :: proc() -> plugin.Request {
	update_draw_frame(			&game       );
	return plugin.Request.None;
}

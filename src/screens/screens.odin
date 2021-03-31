package screens;

import "../../ext/raylib"

Game_Screen :: enum {
	LOGO,
	TITLE,
	OPTIONS,
	GAMEPLAY,
	ENDING
};

Screen :: struct {

	// ------------------------------
	// LOGO
	frames_counter				: i32,
	finish_screen					: i32,

	logo_position_x				: i32,
	logo_position_y				: i32,

	letters_count					: i32,

	top_side_rec_width		: i32,
	left_side_rec_height	: i32,

	bottom_side_rec_width : i32,
	right_side_rec_height : i32,

	raylib_text						: [8]u8,  // raylib text array, max 8 letters
	state									: i32,    // Tracking animation states (State Machine)
	alpha									: f32,    // Useful for fading

	odin_logo_anim        : raylib.Texture2D,
	odin_logo_position    : raylib.Vector2,
	odin_logo_frame_rect  : raylib.Rectangle,
	odin_logo_frame_cnt   : i32,

	camel_anim            : raylib.Texture2D,
	camel_position        : raylib.Vector2,
	camel_frame_rect      : raylib.Rectangle,
	camel_frame_cnt       : i32,

	accept_input          : bool,
};

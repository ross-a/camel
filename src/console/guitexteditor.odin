package console;

import "core:mem"
import "core:strings"

import	"../../ext/raylib"
import	"../../ext/raygui"

// Text editor control (Advanced text box, no input yet, but there is selection (but no copy and paste yet))
gui_text_editor :: proc (bounds : raylib.Rectangle, text : string, textSize : int, editMode : bool) -> bool
{
	using raylib;
	using raygui;

  @static cursor					: Rectangle = {0,0,0,0};  // Cursor position and size
  @static framesCounter		: i32 = 0;						    // Blinking cursor frames counter
  @static cursorCodepoint : i32 = -1;
  @static selectStartCp		: i32 = -1;
  @static selectLengthCp	: i32 = 0;

  state : i32 = cast(i32)gui_get_state();
  pressed : bool = false;

  textWrap :bool = true;   // TODO: Word-Wrap vs Char-Wrap -> textWrapMode { NO_WRAP_LOCK, NO_WRAP_OVERFLOW, CHAR_WRAP, WORD_WRAP }

  // WARNING: First string full traversal
	ctext := strings.clone_to_cstring(text);
  codepointCount : i32 = get_codepoints_count(ctext);

  textLen : int = len(text);     // Text length in bytes

  // Update control
  //--------------------------------------------------------------------
  if ((state != GUI_STATE_DISABLED) && !gui_get_locked())
  {
    mousePoint : Vector2 = get_mouse_position();

    if (editMode)
    {
      state = GUI_STATE_PRESSED;
      framesCounter += 1;

      // TODO: Cursor position logic (mouse and keys)

      // Characters selection logic
      if (selectStartCp != -1)
      {
        if (is_key_down(KEY_LEFT_SHIFT) && is_key_pressed(KEY_RIGHT))
        {
          selectLengthCp += 1;
          if (selectLengthCp >= (codepointCount - selectStartCp)) {
						selectLengthCp = codepointCount - selectStartCp;
					}
        }

        if (is_key_down(KEY_LEFT_SHIFT) && is_key_pressed(KEY_LEFT))
        {
          selectLengthCp -= 1;
          if (selectLengthCp < 0) do selectLengthCp = 0;
        }
      }

      //key : i32 = get_key_pressed();

      // TODO: On key pressed, place new character in cursor position

      // Exit edit mode logic
      if (is_key_pressed(KEY_ENTER) || (!check_collision_point_rec(mousePoint, bounds) && is_mouse_button_pressed(0))) do  pressed = true;
    }
    else
    {
      if (check_collision_point_rec(mousePoint, bounds))
      {
        state = GUI_STATE_FOCUSED;
        if (is_mouse_button_pressed(0)) do pressed = true;
      }
    }

    if (pressed)
    {
      // Exiting edit mode, reset temp variables
      framesCounter = 0;
      cursor = (Rectangle){0,0,0,0};

      cursorCodepoint = -1;
      selectStartCp = -1;
      selectLengthCp = 0;
    }
  }
  //--------------------------------------------------------------------

  // Draw control
  //--------------------------------------------------------------------
  draw_rectangle_lines_ex(bounds, gui_get_style(TEXTBOX, BORDER_WIDTH), fade(get_color(gui_get_style(TEXTBOX, BORDER + (state*3))), gui_get_alpha()));

  if (state == GUI_STATE_PRESSED) {
		draw_rectangle(cast(i32)bounds.x + gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.y + gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.width - 2*gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.height - 2*gui_get_style(TEXTBOX, BORDER_WIDTH), fade(get_color(gui_get_style(TEXTBOX, BASE_COLOR_PRESSED)), gui_get_alpha()));
	} else if (state == GUI_STATE_DISABLED) {
		draw_rectangle(cast(i32)bounds.x + gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.y + gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.width - 2*gui_get_style(TEXTBOX, BORDER_WIDTH), cast(i32)bounds.height - 2*gui_get_style(TEXTBOX, BORDER_WIDTH), fade(get_color(gui_get_style(TEXTBOX, BASE_COLOR_DISABLED)), gui_get_alpha()));
	}

  font : Font  = get_font_default();
  scaleFactor : f32 = cast(f32)gui_get_style(DEFAULT, TEXT_SIZE)*2/cast(f32)font.base_size / 2;														// Character quad scaling factor
	textOffsetY : f32 = 0.0;																																																// Offset between lines (on line break '\n')
  textOffsetX : f32 = mem.ptr_offset(font.recs,'\n').width*scaleFactor + cast(f32)gui_get_style(DEFAULT, TEXT_SPACING);;	// Offset X to next character to draw
	// TODO: possibly fix it so lines don't start with offset_x based on newline width

  for i,cp:=0,0; i < textLen; i+=1
  {
    // Get next codepoint from byte string and glyph index in font
    codepointByteCount : i32 = 0;
		buf := make([]byte, 2);
		buf[0] = text[i];
		buf[1] = 0;

    codepoint : i32 = get_next_codepoint(cstring(&buf[0]), &codepointByteCount);
    index : int = cast(int)get_glyph_index(font, codepoint);

		rx := bounds.x + textOffsetX + cast(f32)mem.ptr_offset(font.chars,index).offset_x * scaleFactor;
		ry := bounds.y + textOffsetY + cast(f32)mem.ptr_offset(font.chars,index).offset_y * scaleFactor;
		rw := mem.ptr_offset(font.recs,index).width * scaleFactor;
		rh := mem.ptr_offset(font.recs,index).height * scaleFactor;
    rec : Rectangle = { rx, ry, rw, rh };

    // Automatic line break to wrap text inside box
    if (textWrap && ((rec.x + rec.width) >= (bounds.x + bounds.width)))
    {
      textOffsetY += ((cast(f32)font.base_size * 1.5) * scaleFactor);
      textOffsetX = 0.0;

      // Recalculate drawing rectangle position
			rx = bounds.x + textOffsetX + cast(f32)mem.ptr_offset(font.chars,index).offset_x * scaleFactor;
			ry = bounds.y + textOffsetY + cast(f32)mem.ptr_offset(font.chars,index).offset_y * scaleFactor;
			rw = mem.ptr_offset(font.recs,index).width * scaleFactor;
			rh = mem.ptr_offset(font.recs,index).height * scaleFactor;

      rec = (Rectangle){ rx, ry, rw, rh };
    }

    // Check selected codepoint
    if (editMode)
    {
      if (is_mouse_button_pressed(MOUSE_LEFT_BUTTON) && check_collision_point_rec(get_mouse_position(), rec))
      {
        cursor = rec;
        cursorCodepoint = cast(i32)cp;
        selectStartCp = cursorCodepoint;
        selectLengthCp = 0;

        // TODO: Place cursor at the end if pressed out of text
      }

      // On mouse left button down allow text selection
      if ((selectStartCp != -1) && is_mouse_button_down(MOUSE_LEFT_BUTTON) && check_collision_point_rec(get_mouse_position(), rec))
      {
        if (cast(i32)cp >= selectStartCp) {
					selectLengthCp = cast(i32)cp - selectStartCp;
        } else if (cast(i32)cp < selectStartCp) {
          //int temp = selectStartCp;
          //selectStartCp = cp;
          //selectLengthCp = temp - selectStartCp;
        }
      }
    }

    if (codepoint == '\n')    // Line break character
    {
      // NOTE: Fixed line spacing of 1.5 line-height
      // TODO: Support custom line spacing defined by user
      textOffsetY += (cast(f32)font.base_size * 1.5) * scaleFactor;
      textOffsetX = 0.0;
    }
    else
    {
      // Draw codepoint glyph
      if ((codepoint != ' ') && (codepoint != '\t') && ((rec.x + rec.width) < (bounds.x + bounds.width)))
      {
				// TODO color code... put in color control codes???:
				//_log_level_strings := []string{
				//	"[Debug]:",
				//	"[Info]:",
				//	"[Warning]:",
				//	"[Error]:",
				//	"[Fatal]:",
				//	"\\\\:",
				//};

        draw_texture_pro(font.texture, mem.ptr_offset(font.recs,index)^, rec, (Vector2){ 0, 0 }, 0.0, get_color(gui_get_style(DEFAULT, TEXT_COLOR_NORMAL)));
      }

      // TODO: On text overflow do something... move text to the left?
    }

    // Draw codepoints selection from selectStartCp to selectLengthCp
    if (editMode && (selectStartCp != -1) && ((cast(i32)cp >= selectStartCp) && (cast(i32)cp <= (selectStartCp + selectLengthCp)))) {
			rec.width += cast(f32)gui_get_style(DEFAULT, TEXT_SPACING);
			draw_rectangle_rec(rec, fade(MAROON, 0.3)); // TODO: selection color
		}

    if (mem.ptr_offset(font.chars,index).advance_x == 0) {
			textOffsetX += mem.ptr_offset(font.recs,index).width*scaleFactor + cast(f32)gui_get_style(DEFAULT, TEXT_SPACING);
		} else {
			textOffsetX += cast(f32)mem.ptr_offset(font.chars,index).advance_x*scaleFactor + cast(f32)gui_get_style(DEFAULT, TEXT_SPACING);
		}

    i += cast(int)(codepointByteCount - 1);   // Move text bytes counter to next codepoint
    cp += 1;
  }

  // Draw blinking cursor
  if (editMode && ((framesCounter/20)%2 == 0)) {
		draw_rectangle_rec(cursor, fade(get_color(gui_get_style(TEXTBOX, BORDER_COLOR_PRESSED)), gui_get_alpha()));
	}

  //--------------------------------------------------------------------
  return pressed;
}

gui_text_input_box_ex :: proc(bounds : raylib.Rectangle, text : ^string, textSize : int, editMode : bool) -> bool
{
	using raylib;
	using raygui;

	STR_BUFF_INC :: 255;

  @static framesCounter : i32 = 0;           // Required for blinking cursor

	state : i32 = cast(i32)gui_get_state();
  pressed : bool = false;
	ctext : cstring = strings.clone_to_cstring(text^);
	text_width : f32 = cast(f32)get_text_width(ctext); // this NEEDS gui_set_font() to be set

  cursor : Rectangle = {
    bounds.x + cast(f32)gui_get_style(TEXTBOX, TEXT_PADDING) + text_width + 2,
    bounds.y + bounds.height/2 - cast(f32)gui_get_style(DEFAULT, TEXT_SIZE),
    1,
    cast(f32)gui_get_style(DEFAULT, TEXT_SIZE)*2
  };

  // Update control
  //--------------------------------------------------------------------
  if ((state != GUI_STATE_DISABLED) && !gui_get_locked())
  {
    mousePoint : Vector2 = get_mouse_position();

    if (editMode)
    {
      state = GUI_STATE_PRESSED;
      framesCounter += 1;

      key : i32 = get_key_pressed();      // Returns codepoint as Unicode
      keyCount : int = 0;
			for i:=0; i<len(text^); i+=1 {
				if text^[i] == 0 {
					break;
				}	else {
					keyCount += 1;
				}
			}
			btextarr := make([]byte, STR_BUFF_INC + keyCount);
			btext := &btextarr[0];
			defer delete(btextarr);
			mem.zero(btext, STR_BUFF_INC + keyCount);
			mem.copy(btext, strings.ptr_from_string(text^), keyCount);

      // Only allow keys in range [32..125]
      if (keyCount < (textSize - 1))
      {
        maxWidth : i32 = (cast(i32)bounds.width - (gui_get_style(TEXTBOX, TEXT_INNER_PADDING)*2));

        if ((cast(i32)text_width < (maxWidth - gui_get_style(DEFAULT, TEXT_SIZE))) && (key >= 32))
        {
          byteLength : i32 = 0;
          textUtf8 := string(codepoint_to_utf8(key, &byteLength));

          for i : i32 = 0; i < byteLength; i+=1
          {
						mem.set(mem.ptr_offset(btext, keyCount), textUtf8[i], 1);
            keyCount += 1;
          }

					mem.set(mem.ptr_offset(btext, keyCount), 0, 1);
        }
      }

      // Delete text
      if (keyCount > 0)
      {
        if (is_key_pressed(KEY_BACKSPACE))
        {
          keyCount -= 1;
					mem.set(mem.ptr_offset(btext, keyCount), 0, 1);
          framesCounter = 0;
          if (keyCount < 0) do keyCount = 0;
        }
        else if (is_key_down(KEY_BACKSPACE))
        {
          if ((framesCounter > TEXTEDIT_CURSOR_BLINK_FRAMES) && (framesCounter%2) == 0) do keyCount -= 1;
					mem.set(mem.ptr_offset(btext, keyCount), 0, 1);
          if (keyCount < 0) do keyCount = 0;
        }
      }

			if (is_key_pressed(KEY_GRAVE) != true) { // ignore this key.. it brings console up or down
				if (is_key_pressed(KEY_ENTER) ||
						(!check_collision_point_rec(mousePoint, bounds) && is_mouse_button_pressed(MOUSE_LEFT_BUTTON))
					 ) {
					pressed = true;
				}

				// Check text alignment to position cursor properly
				textAlignment := gui_get_style(TEXTBOX, TEXT_ALIGNMENT);
				if (textAlignment == GUI_TEXT_ALIGN_CENTER) do cursor.x = bounds.x + text_width/2 + bounds.width/2 + 1;
				else if (textAlignment == GUI_TEXT_ALIGN_RIGHT) do cursor.x = bounds.x + bounds.width - cast(f32)gui_get_style(TEXTBOX, TEXT_INNER_PADDING);

				delete(text^);
				text^ = strings.clone(strings.string_from_ptr(btext, keyCount));
			}
    }
    else
    {
      if (check_collision_point_rec(mousePoint, bounds))
      {
        state = GUI_STATE_FOCUSED;
        if (is_mouse_button_pressed(MOUSE_LEFT_BUTTON)) do pressed = true;
      }
    }

    if (pressed) do framesCounter = 0;
  }

  //--------------------------------------------------------------------
  // Draw control
  //--------------------------------------------------------------------
  if (state == GUI_STATE_PRESSED) {
    gui_draw_rectangle(bounds, gui_get_style(TEXTBOX, BORDER_WIDTH), fade(get_color(gui_get_style(TEXTBOX, BORDER + (state*3))), gui_get_alpha()), fade(get_color(gui_get_style(TEXTBOX, BASE_COLOR_PRESSED)), gui_get_alpha()));

    // Draw blinking cursor
    if (editMode && ((framesCounter/20)%2 == 0)) {
			gui_draw_rectangle(cursor, 0, BLANK, fade(get_color(gui_get_style(TEXTBOX, BORDER_COLOR_PRESSED)), gui_get_alpha()));
		}
  } else if (state == GUI_STATE_DISABLED) {
    gui_draw_rectangle(bounds, gui_get_style(TEXTBOX, BORDER_WIDTH), fade(get_color(gui_get_style(TEXTBOX, BORDER + (state*3))), gui_get_alpha()), fade(get_color(gui_get_style(TEXTBOX, BASE_COLOR_DISABLED)), gui_get_alpha()));
  } else {
		gui_draw_rectangle(bounds, 1, fade(get_color(gui_get_style(TEXTBOX, BORDER + (state*3))), gui_get_alpha()), BLANK);
	}

  gui_draw_text(ctext, get_text_bounds(TEXTBOX, bounds), gui_get_style(TEXTBOX, TEXT_ALIGNMENT), fade(get_color(gui_get_style(TEXTBOX, TEXT + (state*3))), gui_get_alpha()));
  //--------------------------------------------------------------------

  return pressed;
}

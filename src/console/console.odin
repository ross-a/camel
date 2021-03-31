package console;

import  "core:os";
import  "core:fmt";
import  "core:log";
import  "core:time";
import  "core:strings";

import	"../../ext/raylib"
import	"../../ext/raygui"

OUTPUT_TO_CLI			:: true;
OUTPUT_TO_FILE		:: false;
OUTPUT_TO_SCREEN	:: true;
_BUF_SIZE					:: 4096;

CommandProc :: #type proc([]string);

/*
Logger_Level :: enum uint {
	Debug   = 0,
	Info    = 10,
	Warning = 20,
	Error   = 30,
	Fatal   = 40,
}
*/
_log_level_strings := []string{
  "[Debug]:",
  "[Info]:",
  "[Warning]:",
  "[Error]:",
	"[Fatal]:",
	"\\\\:",
};
LogData :: struct {
  input_buf							: [256]u8,
  history								: [dynamic]string,
  commands							: map[string]CommandProc,
	log_file							: os.Handle,
  log_file_name					: string,

  _scroll_to_bottom			: bool,
  _history_pos					: int,

	text_box_text					: string,
	text_box_edit_mode		: bool,
	text_box_panel_scroll : raylib.Vector2,
	input_box_text        : string,
}

log :: proc (level: log.Level, text: string, loc := #caller_location) {
	using raylib;
	using raygui;

	when OUTPUT_TO_CLI {
		cli_print_log(level, text, loc);
	}
	when OUTPUT_TO_FILE {
		file_print_log(level, text, loc);
	}
	when OUTPUT_TO_SCREEN {
		ld : ^LogData = cast(^LogData)context.logger.data;
		if (len(ld.text_box_text) == 0) {
			// fix up TEXT_INNER_PADDING, by adding +1
			using raygui;
			padding := gui_get_style(cast(i32)GuiControl.TEXTBOX, cast(i32)GuiTextBoxProperty.TEXT_INNER_PADDING);
			gui_set_style(cast(i32)GuiControl.TEXTBOX, cast(i32)GuiTextBoxProperty.TEXT_INNER_PADDING, padding+1);

			ld.text_box_panel_scroll = (raylib.Vector2) {0,0};

			add_default_commands();
		}
		screen_print_log(level, text, loc);
		ld.text_box_panel_scroll.y -= 20;
	}
}

cli_print_log :: proc(level : log.Level, text : string, loc := #caller_location) {

  NORM        :: "\x1b[0m";

  FOR_BLACK   :: "\x1b[30m";
  FOR_RED     :: "\x1b[31m";
  FOR_GREEN   :: "\x1b[32m";
  FOR_YELLOW  :: "\x1b[33m";
  FOR_BLUE    :: "\x1b[34m";
  FOR_MAGENTA :: "\x1b[35m";
  FOR_CYAN    :: "\x1b[36m";
  FOR_WHITE   :: "\x1b[37m";

  BACK_BLACK   :: "\x1b[40m";
  BACK_RED     :: "\x1b[41m";
  BACK_GREEN   :: "\x1b[42m";
  BACK_YELLOW  :: "\x1b[43m";
  BACK_BLUE    :: "\x1b[44m";
  BACK_MAGENTA :: "\x1b[45m";
  BACK_CYAN    :: "\x1b[46m";
  BACK_WHITE   :: "\x1b[47m";

	h : os.Handle = os.stdout;
  level_col := FOR_GREEN;
  #partial switch level {
    case log.Level.Warning : {
      h = os.stderr;
      level_col = FOR_YELLOW;
    }

    case log.Level.Error : {
      h = os.stderr;
      level_col = FOR_RED;
    }
  }

	idx := cast(int)level / 10;
  fmt.fprintf(h, "%s%s %s%s", level_col, _log_level_strings[idx], NORM, text);
}

file_print_log :: proc(level : log.Level, text : string, loc := #caller_location) {
	// create and open a log file with current system time
	ld : ^LogData = cast(^LogData)context.logger.data;
  buf := make([]u8, 255);
  if len(ld.log_file_name) <= 0 {
    st := time.now();
		day := time.day(st);
		month := time.month(st);
		year := time.year(st);
		hour, mins, sec := time.clock(st);
    ld.log_file_name = fmt.bprintf(buf[:], "%d-%d-%d_%d%d%d.log",
                                               day, month, year,
                                               hour, mins, sec);
		ld.log_file, _ = os.open(ld.log_file_name, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0);
  }

	idx := cast(int)level / 10; // level is multiples of 10
	str := fmt.bprintf(buf[:], "%s %s", _log_level_strings[idx], text);

  os.seek(ld.log_file, 0, 2); // goto end of file
  os.write(ld.log_file, transmute([]u8)str);
	os.flush(ld.log_file);
}

screen_print_log :: proc(level : log.Level, text : string, loc := #caller_location) {
	// add text to TextBoxText[]
	ld : ^LogData = cast(^LogData)context.logger.data;

	l := len(text);
	if (l + len(ld.text_box_text)) > _BUF_SIZE {
		ld.text_box_text = ld.text_box_text[l:];
	}
	idx := cast(int)level / 10; // level is multiples of 10
	ld.text_box_text = fmt.tprintf("%s%s %s", ld.text_box_text, _log_level_strings[idx], text);
}

count_newlines :: proc(s: string) -> int {
	cnt := 0;
	for r, _ in s {
		if r == '\n' {
			cnt +=1;
		}
	}
	return cnt;
}

update_draw_console :: proc() {
	using raylib;
	using raygui;

	ld : ^LogData = cast(^LogData)context.logger.data;

	// Update ----------------------------
	sw : f32 = cast(f32)get_screen_width();
	sh : f32 = cast(f32)get_screen_height();
	lines := count_newlines(ld.text_box_text);

	font : Font  = get_font_default(); // TODO: centeralize the code to change font in the controls used here
  scaleFactor : f32 = cast(f32)gui_get_style(DEFAULT, TEXT_SIZE)*2/cast(f32)font.base_size / 2;						// Character quad scaling factor
	lines *= cast(int)((cast(f32)font.base_size * 1.5) * scaleFactor);

	panel_rec := (Rectangle) {0,0,sw,sh/3};
	panel_content_rec := (Rectangle) {0,0,sw - 2*cast(f32)gui_get_style(DEFAULT, BORDER_WIDTH) - cast(f32)gui_get_style(LISTVIEW, SCROLLBAR_WIDTH), cast(f32)lines};

	// Draw ------------------------------
	view := gui_scroll_panel(panel_rec, panel_content_rec, &ld.text_box_panel_scroll);


	// TODO: show history, show log, clear, etc...
	begin_scissor_mode(cast(i32)view.x, cast(i32)view.y, cast(i32)view.width, cast(i32)view.height);
	if (gui_text_editor((Rectangle){panel_rec.x + ld.text_box_panel_scroll.x, panel_rec.y + ld.text_box_panel_scroll.y, panel_content_rec.width, panel_content_rec.height }, ld.text_box_text, _BUF_SIZE, ld.text_box_edit_mode)) {
		ld.text_box_edit_mode = !ld.text_box_edit_mode;
	}
	end_scissor_mode();

	// text box for command input
	enter := gui_text_input_box_ex((Rectangle){panel_rec.x, panel_rec.y+panel_rec.height, panel_rec.width, 25}, &ld.input_box_text, 256, true);
	if enter {
		// look up command and  do command
		execute_command(ld.input_box_text);
		// clear command input
		ld.input_box_text = "";
	}
}

add_command :: proc(name : string, p : CommandProc) {
	ld : ^LogData = cast(^LogData)context.logger.data;
  ld.commands[name] = p;
}

default_help_command :: proc(args : []string) {
	ld : ^LogData = cast(^LogData)context.logger.data;
  log.log(log.Level.Info, "Available Commands: ");
  for key, _ in ld.commands {
    log.logf(log.Level.Info, "\t%s", key);
  }
}

default_clear_command :: proc(args : []string) {
  clear_console();
}

add_default_commands :: proc() {
  add_command("Clear", default_clear_command);
  add_command("Help",  default_help_command);
}

clear_console :: proc() {
	ld : ^LogData = cast(^LogData)context.logger.data;

	ld.text_box_text = "";
}

execute_command :: proc(cmdString : string) -> bool {
	ld : ^LogData = cast(^LogData)context.logger.data;

  names := strings.split(cmdString, " ");
	name := strings.trim_space(names[0]);

  if cmd, ok := ld.commands[name]; ok {
		args : [dynamic]string;
		if len(cmdString) != len(name) {
      p := 0;
      newStr := cmdString[len(name)+1:];
      for r, i in newStr {
				if r == ' ' {
          append(&args, newStr[p:i]);
          p = i+1;
        }

        if i == len(newStr)-1 {
          append(&args, newStr[p:i+1]);
        }
      }
    }
    cmd(args[:]);
    return true;
  }
  return false;
}

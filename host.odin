package host

import "core:os"
import "core:log"
import "core:fmt"
import "core:time"
import "core:path"
import "core:runtime"
import "ext/raylib"
import "src/plugin"
import "src/screens"
import "src/console"

COMPILE_GAME :: "../Odin/odin build src/game.odin -vet -build-mode=dll -out=\"game.dll\" -debug";
host_context : ^runtime.Context;

when os.OS == "windows" {
  import "core:sys/win32"
	import "src/reloader_thread"

	compile_game_dll :: proc() -> bool {
		startup_info : win32.Startup_Info;
		startup_info.cb = size_of(win32.Startup_Info);

		process_information: win32.Process_Information;

		if ok := win32.create_process_a(nil, COMPILE_GAME, nil, nil, false, 0, nil,  nil, &startup_info, &process_information); !ok {
			fmt.println("could not invoke build script");
			return false;
		}

		if win32.WAIT_OBJECT_0 != win32.wait_for_single_object(process_information.process, win32.INFINITE) {
			fmt.println("ERROR invoking build batch file");
			return false;
		}
		// TODO: something like win32.destroy_handle(process_information.process);
		return true;
	}
}

log_custom :: proc (data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
	t := time.now();
	h, m, s := time.clock(t);
	if h > 12 do h -= 12;

	str := fmt.tprintf("[%02d:%02d:%02d] %s\n", h,m,s, text);
	console.log(log.Level.Info, str);
}

raylib_log_custom :: proc "c" (msg_type : i32, text : cstring) {
	using log;
	context = host_context^;

	level := runtime.Logger_Level.Info;

	logger := context.logger;
	if logger.procedure == nil {
		return;
	}
	if level < logger.lowest_level {
		return;
	}

	str := fmt.tprintf("[raylib] %s", text);
	log_custom(logger.data, level, str, logger.options);
}

main :: proc() {
  using raylib;
  using plugin;

  set_config_flags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
	screen_width : i32 = 32;
	screen_height : i32 = 32;

	// Log Custom
	c := runtime.default_context();
	host_context = &c;
	host_context.logger.procedure = log_custom;
	host_context.logger.data = &console.LogData{};
	context = c;

	set_trace_log_callback_no_va(raylib_log_custom);

  // Create the window
  init_window(screen_width, screen_height, "project pleonasm");
	screen_width = get_monitor_width(0); // TODO: change monitor number in options screen
	screen_height = get_monitor_height(0);
	set_window_position(64,64);
	set_window_size(screen_width-256, screen_height-128);
  set_window_position(40, 40);  // TODO get from options file?
  set_target_fps(60);
  defer close_window();

	// Audio
  init_audio_device();
  defer close_audio_device();

  // Load the plugin
	if !os.exists("game.dll") do compile_game_dll();
  plugin: Plugin;
  if !plugin_load(&plugin, "game.dll", screens.Game_Screen.LOGO) {
    fmt.println("ERROR loading game.dll");
    return;
  }
	log.logf(log.Level.Info, "%s %s %s", "game.dll", "loaded at time=", time.now()); // TODO time
  defer plugin_unload(&plugin);

  // kick off live reload watcher thread
  when os.OS == "windows" {
    reloader := reloader_thread.start(compile_game_dll, "src");
    defer reloader_thread.finish(reloader);
  }

  // Game loop - calls game.dll update_and_draw()
  RELOAD_INTERVAL_MS:f32 : 0.25;
  reload_timer := RELOAD_INTERVAL_MS;
  for !window_should_close() {
    force_reload := false;
    #partial switch plugin.update_and_draw_proc() {  // ------------------------------
      case .Reload: force_reload = true;
      case .Quit: return;
    }

    needs_reload_check := false;
    if !force_reload {
      reload_timer -= get_frame_time();
      for reload_timer < 0 {
        reload_timer += RELOAD_INTERVAL_MS;
        needs_reload_check = true;
      }
    }

    if needs_reload_check || force_reload {
      plugin_maybe_reload(&plugin, force_reload);
    }
  }
}

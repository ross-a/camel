package gb_generate

import "core:fmt"
import "core:os"
import "core:strings"
import "./bindgen"
import "./preprocessed/aux_data"

when os.OS == "windows" {
  import "core:sys/win32"

  mkdir_if_not_exist :: proc(dir: string) -> os.Errno {
    dir_wstr := win32.utf8_to_wstring(dir, context.temp_allocator);
    if win32.Bool(false) == win32.create_directory_w(dir_wstr, nil) do return os.Errno(win32.get_last_error());
    return os.ERROR_NONE;
  }

	win_shell :: proc(cmd : string, err_msg : string) -> bool {
		cmdline := strings.clone_to_cstring(fmt.tprint("cmd /c ", cmd));

    startup_info: win32.Startup_Info = { cb = size_of(win32.Startup_Info) };
    process_information: win32.Process_Information;
    if ok := win32.create_process_a(nil, cmdline, nil, nil, false, 0, nil,  nil, &startup_info, &process_information); !ok {
      fmt.eprintln("could not invoke build script");
      return false;
    }

    if win32.WAIT_OBJECT_0 != win32.wait_for_single_object(process_information.process, win32.INFINITE) {
      fmt.eprintln(err_msg);
      return false;
    }

		return true;
	}

  preprocess_source :: proc(path_to_source_file: string, path_to_output_file: string) -> bool {
    cmd := fmt.tprint("cl /EP ", path_to_source_file, " > ", path_to_output_file);
		err := fmt.tprint("cl.exe preprocessor did not output to ", path_to_output_file);

		win_shell(cmd, err);

    output, ok := os.read_entire_file(path_to_output_file);
    if !ok {
      fmt.eprintln("read of file failed");
    }
    output_lines := strings.split(cast(string)output, "\n");

    trimmed_lines: [dynamic]string;
    for line in output_lines {
      line_trimmed := strings.trim_space(line);
      if len(line_trimmed) == 0 do continue;
      append(&trimmed_lines, fmt.tprintf("%s\n", line_trimmed));
    }
    trimmed_output := strings.join(trimmed_lines[:], "", context.temp_allocator);

    os.write_entire_file(path_to_output_file, transmute([]u8)trimmed_output);
    // TODO: something like win32.destroy_handle(process_information.process);

    return true;
  }

  preprocess_sources :: proc(path_to_source_files: []string, path_to_output_file: string) -> bool {
		for f,idx in path_to_source_files {
			fout := fmt.tprintf("%s_%d.tmp", path_to_output_file, idx);
			preprocess_source(f, fout);
		}

		cmd_str := "cat";
		for _,idx in path_to_source_files {
			cmd_str = fmt.tprintf("%s %s_%d.tmp", cmd_str, path_to_output_file, idx);
		}
		win_shell(fmt.tprintf("%s > %s", cmd_str, path_to_output_file), "error concat");
		return true;
	}

	postprocess_remove_starting_with :: proc(path_to_source_file: string, lines: []string) {
		for line in lines {
			args: [dynamic]string;
      append(&args, fmt.tprint("sed "));
      append(&args, fmt.tprint("-i "));
      append(&args, fmt.tprintf("/^%s/d ", line));
      append(&args, fmt.tprint(path_to_source_file));

			cmd_line := fmt.tprint(strings.concatenate(args[:]));

			win_shell(cmd_line, "");
		}
	}

	postprocess_bool_fix :: proc(path_to_source_file: string) {
		str := fmt.tprint("sed", "-i", "s/_Bool/bool/g", path_to_source_file);
		win_shell(str, "");

		str = fmt.tprint("sed", "-i", "s/Bool/bool/g", path_to_source_file);
		win_shell(str, "");

		str = fmt.tprint("sed", "-i", "/^bool.::.RlAnon/d ", path_to_source_file);
		win_shell(str, "");
	}

	postprocess_3_d_fix :: proc(path_to_source_file: string) {
		str := fmt.tprint("sed", "-i", "s/3_d/_3d/g", path_to_source_file);
		win_shell(str, "");

		str = fmt.tprint("sed", "-i", "s/2_d/_2d/g", path_to_source_file);
		win_shell(str, "");
	}

	postprocess_showcursor_fix :: proc(path_to_source_file: string) {
		// collides with user32.odin
		str := fmt.tprint("sed", "-i", "s/ShowCursor/ShowCursor_rl/g", path_to_source_file);
		win_shell(str, "");
	}
	postprocess_tracelogcallbacknova :: proc(path_to_source_file: string) {
		str := fmt.tprint("sed", "-i", "\"s/TraceLogCallbackNoVa :: #type proc()/TraceLogCallbackNoVa :: #type proc \\\"c\\\" (msg_type : i32, text : cstring)/g\"", path_to_source_file);
		win_shell(str, "");
	}
}

when os.OS == "linux" {
	mkdir_if_not_exist :: proc(dir: string) -> os.Errno {
		str := fmt.tprint("mkdir", "-p", dir);
		return os.shell("/bin/mkdir", strings.split(str, " "), "");
	}

  preprocess_source :: proc(path_to_source_file: string, path_to_output_file: string) -> bool {
		str  := fmt.tprint("gcc", "-E", "-o" , path_to_output_file, path_to_source_file);
		ret := os.shell("/usr/bin/gcc", strings.split(str, " "), "");
		if (ret == os.ERROR_NONE) {
			str = fmt.tprint("sed", "-i", "/^#/d", path_to_output_file);
			os.shell("/bin/sed", strings.split(str, " "), "");
			return true;
		} else {
			fmt.println("shell error: ", ret);
		}
		return false;
	}

  preprocess_sources :: proc(path_to_source_files: []string, path_to_output_file: string) -> bool {
		for f,idx in path_to_source_files {
			fout := fmt.tprintf("%s_%d.tmp", path_to_output_file, idx);
			preprocess_source(f, fout);
		}

		cmd_str := "cat";
		for _,idx in path_to_source_files {
			cmd_str = fmt.tprintf("%s %s_%d.tmp", cmd_str, path_to_output_file, idx);
		}
		os.shell("/bin/cat", strings.split(cmd_str, " "), path_to_output_file);
		return true;
	}

	postprocess_remove :: proc(path_to_source_file: string, lines: []string) {
		for line in lines {
			args: [dynamic]string;
      append(&args, fmt.tprint("sed"));
      append(&args, fmt.tprint("-i"));
      append(&args, fmt.tprintf("/%s/d", line));
      append(&args, fmt.tprint(path_to_source_file));

			os.shell("/bin/sed", args[:], "");
		}
	}
	postprocess_bool_fix :: proc(path_to_source_file: string) {
		str := fmt.tprint("sed", "-i", "s/_Bool/bool/g", path_to_source_file);
		os.shell("/bin/sed", strings.split(str, " "), "");

		str = fmt.tprint("sed", "-i", "s/Bool/bool/g", path_to_source_file);
		os.shell("/bin/sed", strings.split(str, " "), "");
	}
	postprocess_3_d_fix :: proc(path_to_source_file: string) {
		str := fmt.tprint("sed", "-i", "s/3_d/_3d/g", path_to_source_file);
		os.shell("/bin/sed", strings.split(str, " "), "");

		str = fmt.tprint("sed", "-i", "s/2_d/_2d/g", path_to_source_file);
		os.shell("/bin/sed", strings.split(str, " "), "");
	}
}

generate_raylib_bindings :: proc() {
  options : bindgen.GeneratorOptions;
	options.variableCase = .Snake;
  options.functionCase = .Snake;
  options.pseudoTypeCase = .Pascal;
	options.extra_type_string_lines = []string {
    "LIGHTGRAY :: Color{ 200, 200, 200, 255 };",
    "GRAY      :: Color{ 130, 130, 130, 255 };   // Gray",
    "DARKGRAY  :: Color{ 80, 80, 80, 255 };      // Dark Gray",
    "YELLOW    :: Color{ 253, 249, 0, 255 };     // Yellow",
    "GOLD      :: Color{ 255, 203, 0, 255 };     // Gold",
    "ORANGE    :: Color{ 255, 161, 0, 255 };     // Orange",
    "PINK      :: Color{ 255, 109, 194, 255 };   // Pink",
    "RED       :: Color{ 230, 41, 55, 255 };     // Red",
    "MAROON    :: Color{ 190, 33, 55, 255 };     // Maroon",
    "GREEN     :: Color{ 0, 228, 48, 255 };      // Green",
    "LIME      :: Color{ 0, 158, 47, 255 };      // Lime",
    "DARKGREEN :: Color{ 0, 117, 44, 255 };      // Dark Green",
    "SKYBLUE   :: Color{ 102, 191, 255, 255 };   // Sky Blue",
    "BLUE      :: Color{ 0, 121, 241, 255 };     // Blue",
    "DARKBLUE  :: Color{ 0, 82, 172, 255 };      // Dark Blue",
    "PURPLE    :: Color{ 200, 122, 255, 255 };   // Purple",
    "VIOLET    :: Color{ 135, 60, 190, 255 };    // Violet",
    "DARKPURPLE:: Color{ 112, 31, 126, 255 };    // Dark Purple",
    "BEIGE     :: Color{ 211, 176, 131, 255 };   // Beige",
    "BROWN     :: Color{ 127, 106, 79, 255 };    // Brown",
    "DARKBROWN :: Color{ 76, 63, 47, 255 };      // Dark Brown",

    "WHITE     :: Color{ 255, 255, 255, 255 };   // White",
    "BLACK     :: Color{ 0, 0, 0, 255 };         // Black",
    "BLANK     :: Color{ 0, 0, 0, 0 };           // Blank (Transparent)",
    "MAGENTA   :: Color{ 255, 0, 255, 255 };     // Magenta",
    "RAYWHITE  :: Color{ 245, 245, 245, 255 };   // My own White (raylib logo)",
  };
  {
    using options.parserOptions;
    customExpressionHandlers["__declspec"] = declspec_handler;
    ignoredTokens = []string{"RLAPI", "__cdecl",};
		anonymousPrefix = "rl";
  }

  mkdir_if_not_exist("../ext/raylib");

  outputFile := "../ext/raylib/raylib_bindings.odin";

  // invoke the C preprocessor on the header
  PREPROCESS :: true;

  when PREPROCESS {
    preprocessed_target_file := "./preprocessed/raylib-preprocessed.h";
    preprocess_source("./preprocessed/raylib.h", preprocessed_target_file);
  } else {
    preprocessed_target_file := "./preprocessed/raylib-preprocessed.h";
  }

	when os.OS == "windows" {
		removeLines : []string = {"__pragma", "__declspec"};
		postprocess_remove_starting_with(preprocessed_target_file, removeLines);
	}

	bindgen.generate(
    packageName = "raylib",
    foreignLibrary = "raylib",
    outputFile = outputFile,
    headerFiles = []string{ preprocessed_target_file },
		options = options,
  );

	when os.OS == "linux" {
		removeLines : []string = {"GnucVaList :: BuiltinVaList;", "VaList :: GnucVaList;"};
		postprocess_remove(outputFile, removeLines);
		postprocess_bool_fix(outputFile);
		postprocess_3_d_fix(outputFile);
	}
	when os.OS == "windows" {
		postprocess_bool_fix(outputFile);
		postprocess_3_d_fix(outputFile);
		postprocess_showcursor_fix(outputFile);
		postprocess_tracelogcallbacknova(outputFile);
	}
}

generate_raygui_bindings :: proc() {
  options : bindgen.GeneratorOptions;
	options.variableCase = .Snake;
  options.functionCase = .Snake;
  options.pseudoTypeCase = .Pascal;
	options.odin_imports["_rl"] = "../raylib";
  {
    using options.parserOptions;
    ignoredTokens = []string{};
    customHandlers["RAYGUIDEF"] = rayguidef_handler;
    customExpressionHandlers["__declspec"] = declspec_handler;
		anonymousPrefix = "rlgui";
  }
	options.typeReplacements["Font"] = "_rl.Font";
	options.typeReplacements["Rectangle"] = "_rl.Rectangle";
	options.typeReplacements["Vector2"] = "_rl.Vector2";
	options.typeReplacements["Vector3"] = "_rl.Vector3";
	options.typeReplacements["Texture2D"] = "_rl.Texture2D";
	options.typeReplacements["Color"] = "_rl.Color";

  mkdir_if_not_exist("../ext/raygui");

  outputFile := "../ext/raygui/raygui_bindings.odin";

  bindgen.generate(
    packageName = "raygui",
    foreignLibrary = "../raylib",
    outputFile = outputFile,
    headerFiles = []string{"./preprocessed/raygui-preprocessed.h"},
    options = options,
  );

	when os.OS == "windows" {
		postprocess_bool_fix(outputFile);
	}
}

generate_raymath_bindings :: proc() {
  options : bindgen.GeneratorOptions;
	options.variableCase = .Snake;
  options.functionCase = .Snake;
  options.pseudoTypeCase = .Pascal;
	options.odin_imports["_rl"] = "../raylib";
  {
    using options.parserOptions;
    ignoredTokens = []string{};
    customHandlers["RMDEF"] =  proc(data: ^bindgen.ParserData) {
      bindgen.check_and_eat_token(data, "RMDEF");
    };
    customExpressionHandlers["__declspec"] = declspec_handler;
		anonymousPrefix = "rlmath";
  }
	options.typeReplacements["Vector2"] = "_rl.Vector2";
	options.typeReplacements["Vector3"] = "_rl.Vector3";
	options.typeReplacements["Matrix"] = "_rl.Matrix";
	options.typeReplacements["Quaternion"] = "_rl.Quaternion";
	options.typeReplacements["DualQuaternion"] = "_rl.DualQuaternion";

  mkdir_if_not_exist("../ext/raymath");

  outputFile := "../ext/raymath/raymath_bindings.odin";

  bindgen.generate(
    packageName = "raymath",
    foreignLibrary = "../raylib",
    outputFile = outputFile,
    headerFiles = []string{"./preprocessed/raymath-preprocessed.h"},
    options = options,
  );

	when os.OS == "linux" {
		removeLines : []string = {"RMDEF :: ;"};
		postprocess_remove(outputFile, removeLines);
	}
	when os.OS == "windows" {
		removeLines : []string = {"RMDEF"};
		postprocess_remove_starting_with(outputFile, removeLines);
	}
}

generate_nanosvg_bindings :: proc() {
  options : bindgen.GeneratorOptions;
	options.variableCase = .Snake;
  options.functionCase = .Snake;
  options.pseudoTypeCase = .Pascal;

  mkdir_if_not_exist("../ext/nanosvg");

  outputFile := "../ext/nanosvg/nanosvg_bindings.odin";

	// invoke the C preprocessor on the header
  PREPROCESS :: true;

  when PREPROCESS {
    preprocessed_target_file := "preprocessed/nanosvg-preprocessed.h";
    preprocess_sources([]string{"preprocessed/nanosvg.h","preprocessed/nanosvgrast.h"}, preprocessed_target_file);
  } else {
    preprocessed_target_file := "preprocessed/nanosvg-preprocessed.h";
  }

  bindgen.generate(
    packageName = "nanosvg",
    foreignLibrary = "libnanosvg.a",
    outputFile = outputFile,
    headerFiles = []string{ preprocessed_target_file },
    options = options,
  );
}

main :: proc() {
  generate_raylib_bindings();
  generate_raygui_bindings();
  generate_raymath_bindings();
	generate_nanosvg_bindings();
}

declspec_handler :: proc(data: ^bindgen.ParserData) -> bindgen.LiteralValue
{
  bindgen.check_and_eat_token(data, "__declspec");
  bindgen.eat_line(data);

  return "";
}

macro_make_version :: proc(data : ^bindgen.ParserData) -> bindgen.LiteralValue {
  bindgen.check_and_eat_token(data, "VK_MAKE_VERSION");
  bindgen.check_and_eat_token(data, "(");
  major := bindgen.evaluate_i64(data);
  bindgen.check_and_eat_token(data, ",");
  minor := bindgen.evaluate_i64(data);
  bindgen.check_and_eat_token(data, ",");
  patch := bindgen.evaluate_i64(data);
  bindgen.check_and_eat_token(data, ")");

  return (((major) << 22) | ((minor) << 12) | (patch));
}

rayguidef_handler :: proc(data: ^bindgen.ParserData) {
  bindgen.check_and_eat_token(data, "RAYGUIDEF");
}

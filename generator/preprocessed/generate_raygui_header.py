import os.path
import shutil

this_dir = os.path.realpath(os.path.dirname(__file__))
skipping = False

shutil.copy("C:/raylib/raylib-3.5.0/src/raygui.h", ".")
# note: the above file has #endif for RAYGUI_STANDALONE which is 3 #endif's away... this whole section needs to be skipped

with open(os.path.join(this_dir, "raygui.h")) as f:
    standalone_endif_cnt = 3
    with open(os.path.join(this_dir, "raygui-preprocessed.h"), "w") as out:
        for line in f:
            if "#include" in line:
                continue
            if line == "#if defined(RAYGUI_STANDALONE)\n":
                skipping = True
            if skipping == True and "#endif" in line:
                standalone_endif_cnt -= 1
                if standalone_endif_cnt == 0:
                    skipping = False
            elif "defined(RAYGUI_IMPLEMENTATION)" in line:
                skipping = True
            elif "GuiPropertyElement" in line:  # there is one enum line in IMPLEMENTATION we want
                out.write(line)
            elif "// RAYGUI_IMPLEMENTATION" in line:
                skipping = False
            else:
                if not skipping:
                    out.write(line)

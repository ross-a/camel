import os.path
import shutil

this_dir = os.path.realpath(os.path.dirname(__file__))
skipping = False

shutil.copy("C:/raylib/raylib-3.5.0/src/raylib.h", ".")

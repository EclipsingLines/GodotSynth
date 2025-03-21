#!/usr/bin/env python
import os
import sys

from methods import print_error


libname = "godot_synth"
projectdir = "project/addons"

localEnv = Environment(tools=["default"], PLATFORM="")

customs = ["custom.py"]
customs = [os.path.abspath(path) for path in customs]

opts = Variables(customs, ARGUMENTS)
opts.Update(localEnv)

Help(opts.GenerateHelpText(localEnv))

env = localEnv.Clone()

submodule_initialized = False
dir_name = 'godot-cpp'
if os.path.isdir(dir_name):
    if os.listdir(dir_name):
        submodule_initialized = True

if not submodule_initialized:
    print_error("""godot-cpp is not available within this folder, as Git submodules haven't been initialized.
Run the following command to download godot-cpp:

    git submodule update --init --recursive""")
    sys.exit(1)

env = SConscript("godot-cpp/SConstruct", {"env": env, "customs": customs})

# Add debug symbols and optimization settings
if env["target"] == "template_debug":     # Debug symbols in binary
    env.Append(CPPDEFINES=["DEBUG_ENABLED"])

sources =  Glob("src/synth/*.cpp") + Glob("src/synth/**/*.cpp") + Glob("src/synth/**/**/*.cpp") + Glob("src/synth/**/**/**/*.cpp")

if env["target"] in ["editor", "template_debug"]:
    try:
        doc_data = env.GodotCPPDocData("src/gen/doc_data.gen.cpp", source=Glob("doc_classes/*.xml"))
        sources.append(doc_data)
    except AttributeError:
        print("Not including class reference as we're targeting a pre-4.3 baseline.")

file = "{}{}{}".format(libname, env["suffix"], env["SHLIBSUFFIX"])
filepath = ""

# Set up file paths to match gdextension file
if env["platform"] == "windows":
    # Replace "template_debug" with just "debug" in the filename
    target_type = "debug" if env["target"] == "template_debug" else "release"
    file = "lib{}.{}.{}.{}{}".format(
        libname,
        env["platform"],
        target_type,  # Using our simplified target_type variable
        env["arch"],
        env["SHLIBSUFFIX"]
    )
elif env["platform"] == "macos" or env["platform"] == "ios":
    filepath = "{}.framework/".format(env["platform"])
    target_type = "debug" if env["target"] == "template_debug" else "release"
    file = "lib{}.{}.{}".format(
        libname,
        env["platform"],
        target_type  # Using our simplified target_type variable
    )
else:  # Linux, Android, etc.
    target_type = "debug" if env["target"] == "template_debug" else "release"
    file = "lib{}.{}.{}.{}{}".format(
        libname,
        env["platform"],
        target_type,  # Using our simplified target_type variable
        env["arch"],
        env["SHLIBSUFFIX"]
    )

libraryfile = "godot_synth/bin/{}.{}{}".format(env["platform"], filepath, file)
library = env.SharedLibrary(
    libraryfile,
    source=sources,
)

copy = env.InstallAs("{}/godot_synth/bin/{}{}".format(projectdir, filepath, file), library)

default_args = [library, copy]
Default(*default_args)

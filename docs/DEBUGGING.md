# Debugging with VS Code

[Project guide](README.md) · [Build prerequisites](DEPLOYMENT.md#prerequisites) · [Tests](TESTING_AND_STATUS.md#automated-checks)

Open the repository folder in VS Code on your Linux Plasma desktop. Install the
recommended Microsoft C/C++ extension (CMake Tools is optional), GDB, and
`plasmawindowed` in addition to the normal development dependencies. The launch
configurations assume `/usr/bin/gdb` and `/usr/bin/plasmawindowed`; adjust those
paths for your distribution. No PowerShell installation is needed for these tasks.

## C++ breakpoints

1. Open Run and Debug and select **TLBStacks: standalone widget (C++)**.
2. Set a breakpoint in `Launcher::applicationEntries` or `Launcher::launch`.
3. Press F5. The pre-launch tasks configure a Debug build, build it, and stage the
   widget and plugin under `build/debug/install`.
4. Configure the standalone widget and trigger the corresponding action. Use the
   usual Continue, Step Into, Step Over, Variables, and Call Stack controls.

Breakpoints in the plugin may remain pending until QML loads the native module.
The launch uses the plugin from `build/debug/qml` and the staged widget. It uses
separate configuration, cache, and data directories under `build/debug`, so the
standalone widget starts without your panel's saved stacks. Import a profile or
configure test content there. Profile images are stored in that debug data folder.
These tasks neither run install.ps1 nor restart plasmashell or install system files.

The debug environment still uses the current desktop session and can launch real
applications or move real files to Trash. Use disposable folders for deletion tests.
The explicit data search path includes the staged files plus standard system data;
add any custom system data roots your distribution requires to launch.json.

Select **TLBStacks: native menu tests (C++)** to build and debug the native test
executable instead. It runs offscreen and is useful for repeatable backend/menu
cases. Set its `args` to a QtTest test-function name to narrow the run.

## QML and desktop limits

These configurations provide C++ debugging, not QML/JavaScript breakpoints. QML
warnings and console messages appear in the debug output. Relaunch after editing
QML so the staging task copies current files. Qt Creator is an alternative when
integrated QML debugging is needed; QML debugger startup is not enabled here.

A standalone widget is not a panel containment. Confirm panel sizing, hover,
submenus, screen edges, and Wayland focus behavior in Plasma using the existing
[deployment workflow](DEPLOYMENT.md). Avoid attaching the debugger to plasmashell
for routine work: a breakpoint there pauses the whole shell.

Configuration format follows [VS Code C++ debugging](https://code.visualstudio.com/docs/cpp/launch-json-reference).
See also [KDE widget testing](https://develop.kde.org/docs/plasma/widget/testing/).

## IntelliSense and missing-header squiggles

The C/C++ extension reads `build/debug/compile_commands.json` through the checked-in
`c_cpp_properties.json`. This supplies the compiler's actual Qt/KDE include paths
and defines; do not add system headers one by one. Run **Tasks: Run Task →
TLBStacks: build debug** once after cloning to create the compilation database
and generated Qt headers. Re-run after changing build dependencies.

If stale errors remain, use **C/C++: Reset IntelliSense Database** and reopen the
file. Make sure Microsoft's C/C++ extension is enabled for this workspace. If
clangd is also enabled, choose one C++ language service to avoid duplicate
diagnostics; this repository's IntelliSense configuration targets Microsoft C/C++.

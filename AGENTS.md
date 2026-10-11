# TLBStacks — Agent Instructions

## Project context

KDE Plasma 6 widget (QML + C++/KF6 + CMake, Python profile helper). **Not** a web
project — ignore any web-stack defaults. Two widget packages (`package/` single
stack, `package-group/` group) share one QML module (`com.mattphilmon.tlbstacks`,
files physically in `package/contents/ui/`, registered via `src/CMakeLists.txt`).
Schemas and `cfg_*` contracts are frozen; Apply/Cancel staging belongs to Plasma.

## Build, test, install

- Suite gate: `scripts/ci-run.sh` (gates folder-source, categories, navigation,
  **stack-editor**, **stack-group-runtime**, native-menus, python).
- Extra suites use `QML_IMPORT_PATH="$PWD/build/ci/qml"` (NOT `build/qml` — the
  module lands in `build/ci/qml`; `docs/TESTING_AND_STATUS.md`'s snippet is for
  its own `-B build` flow).
- Dev install: `pwsh install.ps1 -WithGroup` (restarts plasmashell; `-NoRestart`
  skips). Group widget is opt-in everywhere.

## kwin-mcp live-render verification rig

`kwin-mcp` (MCP server, `kwin-mcp` namespace) can drive the widgets in an
**isolated virtual Plasma session** — the only way to verify rendered UI beyond
qmltestrunner. Setup that works:

1. `session_start` with `isolate_home: true, keep_home: true` — note the temp
   home path from the result. Never verify against the real `~/.config`.
2. Seed the temp home: `package/` + `package-group/` →
   `$H/.local/share/plasma/plasmoids/<id>/`; `build/ci/qml/com` →
   `$H/.local/lib64/qt6/qml/com` (build first — the installed `~/.local` module
   may be stale relative to HEAD).
3. Config dialogs can't be opened from `plasmawindowed` (its shell provides no
   `configure` action; our `configure()` silently no-ops there). Instead render
   the config page directly with a qml harness: a root `Item` instantiating
   `ConfigGeneral` from a **relative** directory import (`import "harnessnexto"
   as Group` — the `qml` tool silently exits on absolute-path directory
   imports; copy the package ui dir next to the harness). Run with
   `/usr/lib64/qt6/bin/qml` + `QML_IMPORT_PATH` env via `launch_app`.

### Known blind spots (do not burn cycles rediscovering these)

- **Keyboard text entry does not commit.** `keyboard_type` injects raw evdev
  via EIS; characters render in Qt text fields but never reach the `text`
  property in the virtual session (Return / focus-out do not help). Programmatic
  `.text` set in qmltestrunner works fine — filter/typing behavior is covered by
  `tests/stack-editor/tst_chipbar.qml` + the nested
  `tst_stacksettings.qml` guard; do not re-litigate it through kwin-mcp.
- **Popups/dialogs don't take keyboard focus reliably** — menus opened by mouse
  ignore arrow keys; dialogs ignore Escape. Mouse works: open menus by click,
  activate items by click, cancel dialogs by their Cancel button.
- **Wheel/scroll events don't move ScrollViews** in the virtual session.
  Scrollability is covered by tests + recorded desktop acceptance.
- **AT-SPI is down in isolated sessions** (a11y bus can't spawn) —
  `accessibility_tree` / `find_ui_elements` / `list_windows` fail; use
  `window_geometry` (KWin scripting) instead. Live-desktop `session_connect`
  with `enable_accessibility=true` works if tree inspection is essential.

### Techniques that work

- Mouse clicks are reliable; vision-model absolute coordinates drift ±32px
  between reads. Calibrate by hit/miss, and prefer:
- **Pixel forensics** (host-side ImageMagick/Pillow on the screenshot files):
  focus-ring diffs between Tab steps, cluster analysis (`pxdiag.py`-style cell
  sums), uniform-run scans to locate wide fields and count chip rows. Decisive
  and vision-free.
- **Grid-annotated crops** for the vision lane: crop → 3x scale → red gridlines
  every 50px labeled with original coordinates. Good for bounding boxes; do
  not trust uncalibrated vision point estimates.
- Screenshot file size deltas are a cheap first signal (menu ≈ +5KB, chip cloud
  ≈ +70KB, nothing ≈ ±0.2KB).

## Verified live (2026-10-10, HEAD ≤ 89a8cee) — do not re-verify blindly

Full chrome of both config editors (strip/tree/breadcrumb/segments-with-borders/
tabs/chip cloud/matches preview), add-menu + Custom-launcher dialog +
AppPickerDialog with real catalog, launcher & stack add flows, selection
reactivity (count/tree/matches), Appearance form incl. restored help text,
sidebar Import/Export always visible. Anomalies investigated and closed as
environment artifacts (see commits `cd125d2`, `89a8cee` for the permanent test
guards + spacing fix). The open question ledger lives in the git history of
Oct 7–10 2026 and `docs/STACK_GROUPS.md`.

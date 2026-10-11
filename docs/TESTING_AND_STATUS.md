# Testing and current status

[Project guide](README.md) · [Feature tracker](FEATURE_TRACKER.md)


**Updated:** October 9, 2026. Covers the current working implementation, not just
Git HEAD. The October 5 source checkpoint removes generated build products from
version control while keeping local build files on disk. `.gitignore` excludes
build/test output, local `lib64` staging, and Python caches. Source, tests, docs,
and the supplied historical manual belong in the checkpoint.

## Desktop checks reported by the user

These results describe the local Fedora/Plasma session used during development.
They are not certification for every Plasma version, display layout, or scale.

| Behavior | Latest result |
|---|---|
| Folder cascades open beside the parent; pointer travel and return | Passed |
| One outside click dismisses the native chain and root | Passed after dismissal fixes |
| File patterns in root and nested folders | Passed; directories remain visible |
| Single matching entry leaves no blank extra row | Passed after sizing fix |
| Root grows to its contents; remembered height prevents repeated loading shrink | Passed |
| Move to Trash from root and submenu | Passed; both files confirmed in Dolphin Trash |
| Right-click files without launching | Passed as part of Trash checks |
| Root Up/Down, wrapping, hovered-row handoff in application/category stacks | Passed |
| Live Folder previews stay in parent until Right enters | Passed after preview/entry fixes |
| Right into nested previews; Left back with parent highlight | Passed |
| Hover-opened folder accepts Right without prior Up/Down | Fixed and subsequently exercised by user |
| Left restores launching folder rather than stale hovered row | Latest user report: “Looks good” |
| Enter and Escape | Passed in reported keyboard checks |

The final return-selection patch passed a focused QML test and all 21 native
QtTest cases (including setup/cleanup). A test can pass offscreen while Plasma
behaves differently: earlier popup geometry and Wayland dismissal bugs demonstrated
that limit. Never replace a desktop failure with an automated-pass claim.

## Automated checks

Run from the repository root in a **separate PowerShell terminal**. The offscreen
variables below apply only to that terminal; do not use it to launch the desktop.
Python profile tests require Python 3. C++ tests need the same Qt/KDE development
packages as the plugin; see [Deployment](DEPLOYMENT.md).

`scripts/ci-run.sh` runs the full gate in bash from the repo root: it accepts
an optional build directory (relative or absolute) and resolves the Qt6 test
runner across distributions (Fedora's `qmltestrunner-qt6`, then `qmltestrunner`
and `/usr/lib/qt6/bin/qmltestrunner` on Debian/Ubuntu; override with
`QML_TEST_RUNNER`). After building the plugin it builds and runs both native
QtTest suites offscreen — `tests/native-menus` and the task-tracking
`tests/task-index` — then the QML suites (`folder-source`, `categories`,
`navigation`, `icons`, `stack-editor`, and `stack-group-runtime`, which includes
the `tst_tasks`/`tst_taskmenu` task cases), then the Python profile tests.
`tests/test_release_scripts.sh` adds regression coverage for the release
scripts and also runs in CI after the gate.

```powershell
cmake -S tests/native-menus -B build-tests/native-menus
cmake --build build-tests/native-menus
$env:QT_QPA_PLATFORM = 'offscreen'
$env:QT_QUICK_BACKEND = 'software'
./build-tests/native-menus/folder-popup-test

cmake -S tests/task-index -B build-tests/task-index
cmake --build build-tests/task-index
./build-tests/task-index/task-index-test

# Build the plugin first so the tests load current native types.
cmake -S . -B build
cmake --build build
$env:QML_IMPORT_PATH = (Join-Path $PWD 'build/qml')
$qmlRunner = (Get-Command qmltestrunner-qt6 -ErrorAction SilentlyContinue).Source
if (-not $qmlRunner) { $qmlRunner = '/usr/lib64/qt6/bin/qmltestrunner' }
& $qmlRunner -input tests/folder-source -o -,txt
& $qmlRunner -input tests/categories -o -,txt
& $qmlRunner -input tests/navigation -o -,txt
python3 -m unittest discover -s tests -v
```

Check each command's exit status (`$LASTEXITCODE`) before continuing; these are
interactive commands, not a fail-fast test runner. The fallback QML runner path
is Fedora-specific. A normal install uses `./install.ps1` from the usual terminal.
No automated test here should trash real user files or restart Plasma.

| Suite | Current responsibility |
|---|---|
| `tests/native-menus` | Native cascade/bridge lifecycle, pointer and keyboard handoffs, async loading, capabilities, right-click dispatch, async profiles, reader bounds |
| `tests/task-index` | TaskIndex against a mock tasks model: per-app window state, the ownership rule, append-zone filtering, activate/cycle/step/new-instance |
| `tests/folder-source` | Real FolderSource data reaching QML, filtering and file capabilities |
| `tests/categories` | Category matching, deduplication, ordering |
| `tests/navigation` | Shared root selection, hover handoff, wrapping, empty/stale indexes |
| `tests/test_profiles.py` | Profile versions, settings, image assets, validation and archive safety |

Native trash tests inspect the requested operation through a callback rather than
perform a destructive file operation. Desktop testing separately confirmed actual
Trash delivery. Native tests bypass catalog watching where needed to isolate the
bridge. They do not fully exercise Plasma configuration dialogs or compositor behavior.

`tests/cascades`, `FolderCascadeMenu.qml`, and `tests/check_folder_watcher.py` retain
older experimental paths. They are not evidence for the current QMenu cascades or
FolderSource root. Temporary development harnesses for QML focus/geometry were also
used; not all are checked into the repository. Persistent integration coverage is
still worth improving before larger refactors.

## October code-review follow-up

All seven numbered findings received implementation fixes. This table supersedes
the old descriptions as a current-status summary; it does not erase the original
review or imply that every environmental edge case has been reproduced.

| Finding | Implemented response |
|---|---|
| R1: synchronous profile waits | Async QProcess, busy state, request IDs, overlap rejection and timeout |
| R2: root folder metadata on GUI thread | Shared asynchronous FolderSource/reader descriptors |
| R3: typed icon-size values not immediately committed | Live SpinBox updates |
| R4: unavailable saved apps leave blank popup | Available-entry rendering/sizing and explicit empty-state text |
| R5: obsolete scans accumulate | Shared requests, bounded workers/queue and cooperative abandonment |
| R6: stale missing-app warning/metadata | Refresh on catalog change, with revision dependencies |
| R7: stale launch errors | Activation generation/context checks; no forced reopening on late error |

Follow-up regressions in popup size, dismissal, right-click activation, and keyboard
handoffs were addressed and exercised with the user as recorded above. The observed
Klipper clipboard-preview shutdown crash had a separate stack; no TLBStacks
fix or general Plasma crash resolution is claimed.

## Still to verify

- Screen-edge placement, including cascades forced to open left.
- High-DPI and multi-monitor behavior at the user's actual scales.
- Two widget instances exercised together after the recent navigation changes.
- Full real-editor export/import, Cancel/Apply, custom icons and missing-app flows
  after the asynchronous profile changes.
- Catalog installation/removal while the editor remains open.
- Slow or unavailable mounted folders under real desktop use; work is bounded,
  but a kernel filesystem call cannot be forcibly cancelled.
- Keyboard context-menu invocation (Menu key / Shift+F10) in the desktop session.

Use disposable files for Trash checks. Keep unverified combinations explicitly
unverified instead of marking the whole review as universally tested.

## Planned work

Requests and acceptance criteria are maintained in the [feature tracker](FEATURE_TRACKER.md).
That page owns tooltip polish, mixed application/folder items, and repository cleanup.
This page owns test evidence and remaining verification only.

### F-001 tooltip verification

The user reports improved tooltip behavior after linking each tooltip to its host
window and gating its delay on host visibility. The subsequent application
metadata and display-mode changes built successfully and received positive user
feedback. QML lint and a simplified Qt window-lifecycle test passed. The full
Plasma component could not initialize in the bounded offscreen harness.

Tooltips now appear in both application display modes. Live Folder always shows
filenames; native children use Qt menu tooltips. Application descriptions use the
desktop-entry comment with generic-name fallback.

Remaining targeted checks: rapid mouse/keyboard traversal, dismissal during the
700 ms delay, context menus, folder preview/Right/Left handoff, screen edges,
multiple monitors, and scaling. These combinations are not all confirmed by the
user's general feedback.

### Two-column configuration editor

Selected Applications places the ordered group and shared Up/Down/Remove controls
beside the searchable application catalog. Per-row edit buttons retain custom icon
selection. Categories places searchable checkboxes beside matching applications.
Each pane scrolls independently. Existing configuration assignments and Apply/Cancel
handling are preserved. Static QML checking found no syntax errors; Launcher type
resolution remains unavailable to qmllint. Desktop sizing, selection after reorder
or removal, and icon editing still need interactive verification.

### Activity source initial checks

The plugin builds against PlasmaActivities/Stats 6.7.5. A read-only integration
probe completed a recent-app query with five entries at a limit of five, without
printing history. Profile tests cover new fields, round-trip, legacy defaults,
and invalid values. Static QML checks retain warnings for manually registered
native types; no claim of full QML lint cleanliness is made.

Desktop checks still needed: recent versus frequent ordering, category restriction,
current/all Activities, empty history, profile import/Apply, desktop actions, and
keyboard navigation. Refresh is on opening, not continuous live rearrangement.

Activity first-open follow-up: retain cached entries during refresh, prefetch on
widget initialization, coalesce identical in-flight requests, and limit the query
to twice the requested count for the two possible desktop-ID aliases. Extend the
actual Plasma popup-height correction to this async source. User reported clipped
first rows and repeated-click loading before this correction; desktop retest needed.


### Application icon fallback rendering

With the Plasma/Kirigami runtime installed, run:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmltestrunner-qt6 -input tests/icons -o -,txt
```

This focused renderer suite supplies theme availability as input and checks missing
custom theme/file icons, valid overrides, and generic fallback when both icons are
unavailable. It is separate from the minimal CI suites because it imports Kirigami.
The native caller checks theme availability with `QIcon::hasThemeIcon`; verify the
complete lookup and rendering together in the installed widget.

### CI QML runtime dependencies

Both Fedora CI and release workflows explicitly install `libplasma`,
`kf6-kirigami`, and `kf6-kiconthemes` for editor runtime tests, in addition
to the C++ build dependencies. Development packages alone did not supply
Plasma Components and Kirigami in the minimal container. The dependency fix
in `f5b921e` passed [the full Actions run](https://github.com/mattisking/tlb-stacks/actions/runs/37734823287),
including release-pipeline regression checks.

### CI schema-version regression — October 9, 2026

Both failed runs after the custom-launcher work compiled successfully, then stopped
on a navigation test that still classified group settings version 5 as unsupported.
Versions 5–7 are now valid. The rejection fixture uses version 999, and a separate
check explicitly accepts every supported version (1–7). Icon regression tests are
now included in the shared CI script as well.

The full `scripts/ci-run.sh` gate passed locally after this correction. Run this
complete gate before pushing schema changes; focused editor/profile suites alone
do not cover the navigation suite's compatibility expectations.

### Task tracking verification — October 9, 2026

Running-window tracking ([F-017](FEATURE_TRACKER.md#f-017)) is covered by two
suites in the gate:

- `tests/task-index` (native QtTest, now built and run by `scripts/ci-run.sh`
  beside `tests/native-menus`): TaskIndex window matching and per-app state
  against a mock tasks model — the ownership rule, append-zone filtering of
  unclaimed windows (including windows with no resolvable desktop entry), and
  activate/cycle/step/new-instance, including the request invokables the real
  TasksModel provides.
- `tst_tasks.qml` and `tst_taskmenu.qml` in `tests/stack-group-runtime` (QML,
  offscreen, already run by the gate's existing suite line): the panel
  click-matrix decisions and panel-button identity across task revision
  bumps, plus popup running state with activate-on-click and
  middle-click-new-instance — including exact pre-change behavior whenever
  the task area is null (tracking off or degraded).

Automated passes do not confirm the live desktop: the click matrix and append
zone need a compositor. Work through the manual feel-test checklist below in
the environment of record (Fedora + Wayland) on the installed widget — a
TLBStacks Group containing application launchers and at least one stack, plus
at least one standalone stack:

1. **Launch:** left-click an idle configured application; it starts, and its
   button gains the running indicator.
2. **Activate:** focus another window, then left-click the application's
   button; its most recent window activates.
3. **Minimize:** left-click again while that single window is focused; it
   minimizes.
4. **Grouped cycling:** middle-click the application for a second window,
   then left-click while it is focused; the click cycles to the next window
   instead of minimizing.
5. **Scroll stepping:** scroll the wheel over the application's button; each
   notch steps to its next or previous window.
6. **Middle-click new instance:** middle-click a running application; a new
   window opens. Middle-click an idle application; it launches.
7. **Append zone:** launch an application that is not configured in the
   group; its button appears in the append zone, and disappears again once
   its last window closes.
8. **Popup running dots:** open a stack containing a running application; its
   entry shows the running dot (highlighted while active); clicking the entry
   activates the window; middle-clicking it opens a new one.
9. **Standalone dot:** a standalone TLBStacks stack whose member application
   runs shows the running dot on its panel button.
10. **Degradation check:** the dev box cannot uninstall the plasma-workspace
    QML module, so simulate its absence instead — temporarily rename the
    installed `org.kde/taskmanager` QML directory (Fedora:
    `/usr/lib64/qt6/qml/org/kde/taskmanager`) with root rights, restart Plasma
    (`systemctl --user restart plasma-plasmashell.service`), and confirm both
    widgets still load and behave as pure launchers: no running dots, no
    append zone, and left-click launches. Rename the directory back and
    restart Plasma again to restore task tracking.

Record each step's result here once run; keep failures as bugs with a
reproducible case rather than reopening the feature.

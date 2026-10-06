# Deployment and local Plasma development

[Project guide](README.md) · [Feature tracker](FEATURE_TRACKER.md)


**Updated:** October 5, 2026. Run the commands below from the repository root.
See [testing and status](TESTING_AND_STATUS.md) for desktop results and outstanding checks.

## Prerequisites

Install a C++20 compiler, CMake 3.24 or newer, Extra CMake Modules 6, Qt 6
(Core, QML, Quick, Widgets, Concurrent), and KDE Frameworks 6 development packages
for KIO and KService. Runtime QML imports also require Kirigami, KDE icon themes,
and Plasma components. The installer needs PowerShell (`pwsh`), Python 3,
`kpackagetool6`, and a running Plasma user session managed by systemd.

Package names vary by distribution; this repository does not yet provide a
validated cross-distribution dependency installation command. Qt/Plasma versions
must be compatible with the desktop loading the native module.

## Install from source

From PowerShell, run `./install.ps1`. The script resolves source paths relative
to itself, configures and builds C++, installs the QML module, verifies the
installed binary, updates (or first installs) the widget, and restarts Plasma.
Every native-command failure stops deployment. Use `-NoRestart` only when you
intend to restart Plasma yourself before testing.

The default module location is
`~/.local/lib64/qt6/qml/com/mattphilmon/tlbstacks`, matching this Fedora
installation's existing module. `-InstallPrefix` and `-QmlDirectory` can override
it; a custom QML root must be in the desktop's QML import paths. Installing the
widget package alone does not install the C++ plugin.

The original CMake files had no install rules: `cmake --install build` succeeded
with an empty manifest. The old installed library lacked `applications()` even
though the newly built library exported it. Updating QML therefore called a
method absent from the installed plugin. A restart alone could not fix that.
The explicit rules now install the library, qmldir, and type information. The
manual plugin registers Launcher and FolderSource at runtime. Static QML tools may
not understand these manually registered types; a successful build or syntax check
is not a substitute for loading the installed module in Plasma.

After deployment, open Configure TLBStacks and verify that applications
appear, typing filters them, Enter leaves the dialog open, and changing the group
name still saves. Use Add in the search results and Remove in the selected list, then Apply/OK to save the group. Cancel discards
unapplied changes. Search only filters the list; it preserves selections. Existing
IDs keep their order, newly selected IDs are appended, and unavailable IDs are
preserved. Use Up/Down in the Launcher order list to reorder selected apps, then
Apply/OK to save. This list stays visible regardless of the application search. Plasma supplies cfg_* and cfg_*Default values from main.xml.

Watch desktop messages in a separate PowerShell terminal:

```powershell
journalctl --user -u plasma-plasmashell.service -f
```

Ctrl+C stops only the log viewer. To inspect the native module actually mapped
by Plasma after opening the widget:

```powershell
$plasmaProcessId = (& pgrep -x plasmashell | Select-Object -First 1)
Get-Content "/proc/$plasmaProcessId/maps" | Select-String 'tlbstacks'
```

The mapped path should match the script's `Verified plugin` path and should not
say `(deleted)`. A different path indicates another module copy has precedence.

Each widget instance has its own name, menu icon, and ordered application list.
Use Menu icon → Choose in configuration, then Apply/OK. Reset restores the
default icon; Cancel discards unapplied changes. Add another TLBStacks
widget to create another independent menu and arrange widgets in panel edit mode.

Menu display offers an Icons only mode for the whole group. Names remain available
on hover or keyboard focus. Menu icon size ranges from 16 to 64 logical pixels;
rows and popup width adapt, and the default labeled layout retains 40-pixel rows.
These settings affect popup applications, not the panel button icon size.

Search results contain only applications not already in the group. Remove works
from the selected list, including for an application that is no longer installed.
Click an application icon in the selected list to choose a theme icon, choose an
image file, or reset it. The menu icon has separate Choose, Image, and Reset controls.
Overrides are saved per widget and do not change the system application's icon.
New custom image selections are copied into TLBStacks-managed storage. Older
image selections still reference their original paths until reselected; export
includes those originals as well.
Icon choices follow the same Apply/OK and Cancel behavior as other configuration.
Drag sorting is deferred; Up/Down remains available.


## Portable menu profiles

Configure a widget and choose **Export menu…** to save its current editor settings
and custom images in a ZIP. Export includes unapplied edits. It exports this one
menu, not all widget instances or the Plasma panel layout. Built-in icons remain
theme names, and applications remain desktop IDs; executables are not bundled.

Use **Import menu…** on another TLBStacks widget to load an archive into the
editor. Apply/OK commits the imported settings; Cancel leaves saved settings alone.
Unavailable applications remain in the selected list with a warning so they can
be installed later or removed. Icons missing from the destination theme use the
normal icon-renderer fallback.

Custom images are copied to `$XDG_DATA_HOME/tlbstacks/icons` (normally
`~/.local/share/tlbstacks/icons`) with content-based filenames. Selecting the
same image again reuses the stored copy. Assets are not automatically deleted when
removing an override or cancelling an import, because other widgets may share them.

Profile support requires Python 3, using only its standard library. The native
plugin invokes the packaged helper without a shell. Archives contain `profile.json`
and content-addressed `assets/` images. Imports check format/version, settings,
entry names, lengths, and checksums before writing assets. No archive paths are
extracted directly. Limits: 10 MiB per image, 256 images, and 64 MiB of image data.

Run the profile checks with `python3 -m unittest discover -s tests -v`.

Exports use format version 3; versions 1 and 2 are also accepted. The archive
contains one stack. Combined export of all widget instances remains a separate feature.

Profile operations run asynchronously. The editor shows a working message and
disables its controls until completion. Wait for completion before Apply/OK;
Cancel/closing the editor abandons its result. Completed imports are still staged
until Apply. A slow helper no longer blocks the shell waiting for a result.


## Live folder menus

In configuration, choose **Menu contents → Live folder**, then choose a local
folder. Use `*` for all files or semicolon-separated patterns such as
`*.pdf;*.desktop`. Subfolders remain visible regardless of file patterns. Hidden
files are excluded. Entries sort by name, with folders first.

The root uses background polling at one-second intervals while open; completed
changes update the list. Slow reads never overlap for that source. Hover over a subfolder to open a cascading menu beside it; clicking or pressing
Right also opens it. Move onto a different item in the parent menu to close or
replace that branch. Returning the pointer to the original popup dismisses the native branch.
The root list stays in place, and closing the widget closes all submenus. Long directories scroll. Both icon-only and
labeled display modes work, with names in separate Plasma tooltips.

Files open through KDE's associated application. Local executable files are passed
to KDE's launcher handling; command-line tools needing terminal/argument settings
should be represented by `.desktop` launchers. The first version does not offer
terminal/argument editing or special System Settings/Network sources.

Profile ZIPs contain the folder location and patterns, never the folder's contents.
When moving a profile to another machine, use Choose to remap the folder. Missing
or unreadable folders show a message and are checked again while the popup is open.
Switching back to Selected applications preserves the existing application list.

The current root uses `FolderSource`, not `FolderListModel`.
`tests/check_folder_watcher.py` exercises the older FolderListModel-based path;
it is a historical diagnostic, not validation of the current root source.


Cascading menus use native QWidget QMenu pop-outs anchored to the Plasma Quick
window. Each submenu loads a snapshot on opening and keeps it stable until reopened.
Hover delay is configurable. Root and submenu reads share a private two-worker
reader with at most eight distinct queued/running requests. Identical in-flight
reads are shared, and abandoned subscribers cannot update destroyed UI. A filesystem
call already blocked in the kernel cannot be forcibly interrupted; limits prevent
unbounded duplicate work. Root scans retry on the next poll; busy submenus can be reopened.

The original folder row stays highlighted until the pointer enters the native
pop-out. Returning to the root releases the native branch. Submenus retain native
style sizing; root icons-only/icon-size options do not restyle native child menus.

See [testing and status](TESTING_AND_STATUS.md) for current test commands and their
limits. `tests/cascades` and `FolderCascadeMenu.qml` are legacy experimental QML
cascades, not the native menu path used by the widget.

## Keyboard, pointer, and file actions

All three root sources support Up/Down selection, wrapping, and switching from a
hovered row to keyboard navigation. Selected Applications and Categories share the
application renderer; both use the same root selection helper as Live Folder.
Enter activates the selected item and Escape dismisses. Live Folder adds previews:
selecting a folder opens its submenu after the configured delay, but Right enters
it and selects its first item. Left returns selection to the launching parent row.
Returning from a native submenu must not restore an earlier, stale mouse-hover row.
One outside click dismisses the whole menu chain. Actual pointer movement resumes
mouse navigation. Native Qt menus still implement deeper-level navigation.

Selected Applications offers **Remove from this stack**, which changes the saved
selection without uninstalling or deleting anything. Categories are computed and
do not offer that removal action. Live Folder files offer **Move to Trash** at both
root and native submenu levels. This uses KDE's asynchronous trash operation and
is not permanent deletion. Directory entries do not currently offer Trash.
Right-click must not launch an item. Root contents refresh through polling; reopen
a native submenu to refresh its snapshot after a file change. Trash can be checked
in Dolphin; folders-first sorting can separate items despite deletion-time sorting.

## Popup size and remembered height

The root requests a content-dependent height, capped at 480 logical pixels and,
for Live Folder, 70% of available screen height. A completed one-entry folder list
uses one row rather than leaving a blank second row. Long lists scroll.

Plasma can retain a saved window size even after the content grows. The widget
therefore synchronizes its own applet popup window height, including padding.
`folderHeightCache` remembers the last completed folder height per instance,
keyed by folder URL, filters, and row height. It supplies the initial size during
loading and survives restarts. A new folder/filter combination has no cache yet
and can resize on its first load. The cache is runtime state, not exported profile
content. Do not use cached height as a count of actual entries.

Tooltip changes are tracked in [F-001](FEATURE_TRACKER.md#f-001); that entry owns
the requested behavior and timing decisions.

Unavailable selected application IDs remain stored. Only resolved entries count
toward popup height; a wholly unavailable/empty selection displays explanatory text.
Icon-size typing commits immediately, and configuration warnings refresh with KDE's
application catalog. Launch errors are scoped to current content: old-context
results are ignored, and failures do not forcibly reopen a dismissed popup.

## Import-path and restart troubleshooting

A plugin hash match proves that the installed file matches the build, not that a
running Plasma process has loaded it. Restart Plasma after native changes, and
check the mapped path above when behavior still looks old. A session-only
`QML_IMPORT_PATH` in a terminal does not configure Plasma after reboot. The install
script does not create a persistent desktop import-path setting: a custom module
location must be discoverable in Plasma's own environment. Keep deployment on the
verified local setup unless intentionally changing that configuration.

The historical `applications is not a function` error involved stale installed
native code. `module ... is not installed` instead calls for checking module
location and the desktop's import paths. Neither is fixed merely by reinstalling
the widget's QML package. Do not replace this distinction with a generic restart
recommendation.

## Renaming existing installations

The widget ID is now `com.mattphilmon.tlbstacks`. Plasma treats this as a new
widget, rather than an upgrade of `com.mattphilmon.truelaunchbar`. Existing panel
instances retain their old package and settings; installing does not migrate them.
Export each old menu, install the new package, add a TLBStacks widget, import the
menu, and Apply. Verify the new stack before removing its old panel instance.
Both old TrueLaunchBar and new TLBStacks profile archives are accepted.

New image assets use `tlbstacks/icons`. Existing absolute image references remain
valid; do not delete the old `truelaunchbar/icons` directory while they are in use.
Historical documentation and the original Windows manual retain the original name.

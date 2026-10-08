# Configuration editor redesign — agreed direction

[Project guide](README.md) · [Stack Groups](STACK_GROUPS.md) · [Feature tracker](FEATURE_TRACKER.md#f-015)

Recorded October 7, 2026 after reviewing the user's prototype QML and sampled
frames from their recording. The user is also developing this design separately;
coordinate before replacing it. The shared editor structure over existing settings is now merged on `main` — see [Stack Groups](STACK_GROUPS.md#shared-stack-editor-rebuild-branch-shared-stack-editor)
for what shipped and what is deferred. The remaining sections stay a design
reference for the deferred increments.

## Reference material

User-provided originals (leave unchanged):

- `/home/mattisking/Downloads/files/preview.qml`
- `/home/mattisking/Downloads/files/GroupEditor.qml`
- `/home/mattisking/Downloads/files/ConfigGroup.qml`
- `/home/mattisking/Downloads/files/CategoryPicker.qml`
- `/home/mattisking/Downloads/files/AppPicker.qml`
- `/home/mattisking/Videos/Screencasts/Screencast_20261007_101026.webm`

The recording shows category chips and richer icon controls; the supplied QML
uses a category checklist and icon-name text fields. They are different references,
not an exact implementation pair. The QML wrapper's proposed groupJson schema is
not the project's current storage contract and should not replace it wholesale.

## Direction to preserve

- Clickable panel-order preview at the top, persistent expandable item tree at the
  left, and a focused settings area on the right.
- Contents / Appearance tabs and a searchable application picker shown when adding.
- Share one stack editor between group and standalone widgets. The group supplies
  the tree and preview; standalone opens the same stack editor directly.
- Preserve our existing validated schema, stable IDs, Apply/Cancel staging,
  source-setting retention, profile transport and native data providers.
- Preserve icon chooser, custom image import, reset and missing-icon fallbacks.
- Make expanded selected-application rows selectable for icon editing, eventually
  custom launch arguments. Prototype child rows are currently only summary labels.
- Dynamic category/activity/folder results must be recognizable as previews, not
  editable membership lists. Removing a preview row must not imply source changes.
- Allow independent settings scrolling and a resizable sidebar for smaller windows.
- Group defaults with per-stack overrides are desirable but a separate behavior
  increment: define inheritance and export compatibility, preserving existing
  explicit values. Prototype -1 defaults and broader numeric ranges are not yet
  part of our schema. Likewise launcher labels/icons and drag handles are not proof
  that the underlying capabilities already exist.

## Current status — October 7, 2026

The shared editor is merged on main (46c83b8). Panel right-click item editing
has been dropped by the user for now; the superseded work is stashed. Do not
restore that stash or reconnect groupSelection. Editing happens in the full editor.

The current polish pass fixes scrolling on category/activity/folder pages,
immediate typed numeric updates, managed storage for icon-dialog Browse results,
and icon errors hidden on the Appearance tab. It also adds tree icons, bounded
left-aligned forms, category chip outlines, a compact Export menu, readable folder
paths and clearer direct-launcher wording. All changes preserve existing storage
and profile formats. The user accepted the editor polish after desktop testing, including the compact
Recent layout. Optional orientation and group cascade checks remain tracked in
Stack Groups.

Direct-launcher label/icon appearance is implemented and desktop-accepted; see
[Stack Groups](STACK_GROUPS.md#direct-launcher-appearance).
Selectable application rows in the group tree were accepted on October 7, 2026;
the user confirmed icon changes and Reset. Top-level drag ordering is implemented
and desktop-accepted; see [the test checklist](STACK_GROUPS.md#drag-panel-items-into-order--desktop-test).
Dragging applications and separators within a stack is implemented and
desktop-accepted on October 8, 2026; see [member dragging](STACK_GROUPS.md#drag-selected-applications-and-separators--desktop-test).
Inherited group defaults remain a future increment.

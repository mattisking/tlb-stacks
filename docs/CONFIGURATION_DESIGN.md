# Configuration editor redesign — agreed direction

[Project guide](README.md) · [Stack Groups](STACK_GROUPS.md) · [Feature tracker](FEATURE_TRACKER.md#f-015)

Recorded October 7, 2026 after reviewing the user's prototype QML and sampled
frames from their recording. This is a design reference, not implemented behavior.
The user is also developing this design separately; coordinate before replacing it.

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

## Delivery order / resume point

1. Fix the group-button right-click versus hover-open conflict first. The user
   confirmed selection handoff works but needs repeated attempts to open its menu.
2. Introduce the editor structure over existing settings without losing features.
3. Add selectable child editing and inherited defaults as separate testable changes.

At this checkpoint the configuration shortcut and hover fix are uncommitted pending
retest. Do not report step 6 fully accepted or start replacing the configuration
layout as part of the interaction bugfix. Later implementation should update this
page and the linked delivery tracker rather than leaving conflicting plans.

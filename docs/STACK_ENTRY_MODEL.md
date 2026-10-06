# Shared stack entries and navigation

[Project guide](README.md) · [Feature tracker](FEATURE_TRACKER.md)


**Updated:** October 5, 2026. Internal implementation contract, not a plugin SDK.

## Sources and renderers

Each widget selects one source: `applications`, `categories`, or `folder`.
Selected applications preserve the saved desktop-ID order. Categories compute an
any-category match, deduplicate, and sort applications by name. Both become shared
application entries and render in `main.qml`. Unavailable saved IDs remain stored;
only available entries are rendered, with an explanatory empty state when needed.
Catalog revision changes refresh descriptors and editor warnings.

Live Folder uses asynchronous `FolderSource` at the QML root and native
`FolderPopup` menus for descendants. Both use `folderreader` and `StackEntry::file`.
Files match the same patterns, directories stay visible, hidden entries are
excluded, and ordering is folders-first then name. The root polls while open;
children are stable snapshots until reopened. The reader coalesces identical
in-flight requests, uses two workers, and admits at most eight distinct requests.
Cancellation is cooperative; a blocked filesystem call cannot be interrupted.

## Item description

[stackentry.h](../src/stackentry.h) constructs QVariantMap values:

| Field | Meaning |
|---|---|
| `id` | Desktop ID or file URL; independent of display label |
| `name`, `icon` | Resolved display values; application overrides take precedence |
| `source` | `applications`, `categories`, or `folder` |
| `action`, `target` | `launchApplication` + desktop ID, `openFile` + URL, or `openChildren` + URL |
| `available` | Whether the item resolved when described; not a guarantee it still exists at activation |
| `hasChildren` | Whether opening this item requests a child menu |
| `actions` | Explicit context-action capabilities supplied by the source |

| Source/item | Context capability | Effect |
|---|---|---|
| Selected application | `removeFromStack` | Remove its ID from this widget; do not uninstall or delete files |
| Category application | None | Membership is computed from categories |
| Available local file | `moveToTrash` | Pass its URL to KDE Trash; no permanent-delete fallback |
| Directory | None currently | Open children; directory deletion is not exposed |

Context actions create an operation from the entry. For Trash, `action` becomes
`moveToTrash`; the source and capability remain checked by `Launcher::activateEntry`.
Both QML root and native submenu actions use that dispatcher. Right-click is
consumed separately from launch handling. Capability checks are internal policy,
not a security boundary for future untrusted plugins.

Opening children is not file activation: the renderer supplies the anchor,
filters, and delay to `showFolderMenu`. KIO application/file jobs are asynchronous.
Their errors flow through `activationFailed` (with `fileOpenFailed` retained), and
obsolete activation generations are ignored. Application activation closes the
root when the job starts; file-root activation can leave it open. These outcomes
are not yet one universal close-on-activation policy.

## Navigation contract

[MenuNavigation.js](../package/contents/ui/MenuNavigation.js) shares root selection
rules across all sources: start from the hovered row when switching to keyboard,
otherwise continue the selected row; wrap at both ends; Down starts at the first
row and Up at the last when nothing is selected. Renderers handle focus, visible
highlight, scrolling, activation, and their source-specific context menu.

Live Folder has two distinct states: a submenu can be **open as a preview** while
navigation remains in its parent, or **entered** by Right or pointer movement.
Right selects the first enabled child after asynchronous loading, including when
the preview is already open. Left restores the launching parent row. Escape and
outside dismissal preserve the verified whole-stack behavior.

The QML/native bridge tracks the anchor, native entry state, dismissal, and focus
return. Programmatic closure for parent handoff is distinguished from native
popup dismissal; Wayland need not deliver an outside mouse press to the widget.
The folder root protects keyboard selection from hover notifications generated
when popup grabs change. It records pointer position when keyboard ownership
changes and yields selection to actual pointer movement or an explicit pointer action.

Shared navigation does not mean one renderer: deeper QMenu navigation remains
native. Selected Applications still contains application IDs only. Adding folders
there is a future mixed-item feature, not enabled by this refactor. Such a feature
should reuse `hasChildren` and the navigation contract rather than create another
set of key rules. No plugin SDK or panel/task-manager replacement is introduced.

## Configuration and transport

Settings are per widget. Portable version-3 menu ZIPs include settings and image
assets, not executables or folder contents; imports also accept versions 1 and 2.
Images live in shared content-addressed storage. Import remains staged until Apply;
asset writes can outlive Cancel because images may be shared across widgets.
Profile helpers run asynchronously with a busy state and a 15-second timeout.

`folderHeightCache` is a runtime sizing cache, excluded from profile exports. It
must not become an item identity, source-membership cache, or source of file counts.

See [testing and status](TESTING_AND_STATUS.md) for validation and known limits.

### Shortcut name tooltips

Root rows show tooltips in both display modes after 700 ms on one selection.
Application entries expose an optional `description`: the desktop-entry comment,
falling back to its generic name. Tooltips include it beneath the application name.
Root tooltips use a small, input-transparent Plasma window beside the popup.
Native folder children use Qt menu tooltips with a 700 ms hover delay.
Folder previews suppress their parent root tooltip while open.

Live Folder always shows filenames. Its Icons only control is disabled; the saved
preference is preserved for switching back to an application source. Tooltip timing
is independent of menu opening. See [F-001](FEATURE_TRACKER.md#f-001).

### Application-provided actions

Application entries advertise `desktopActions` when their desktop file supplies
visible actions. The context menu resolves those actions from KService and invokes
them using KIO::ApplicationLauncherJob. Category entries never offer removal;
selected entries retain Remove from this stack below the application actions.
No command strings are constructed by QML. Recent documents are not yet included.

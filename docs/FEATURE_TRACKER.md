# Feature and follow-up tracker

[Project guide](README.md) · [Current model](STACK_ENTRY_MODEL.md) · [Verification](TESTING_AND_STATUS.md)

**Updated:** October 7, 2026. This is the authoritative list of requested future
work. IDs remain stable even when titles or priorities change. Update entries as
requests are clarified; link to implementation and verification rather than copy them.

Statuses: **Planned** (agreed direction, not started), **Needs design** (intent
recorded, details unresolved), **In progress**, **Implemented — needs verification**,
**Verified**, or **Deferred** (explicitly outside current work). No dates are promised.

| ID | Request | Status |
|---|---|---|
| [F-001](#f-001) | Unobtrusive, delayed tooltips | Implemented — needs verification |
| [F-002](#f-002) | Folders alongside selected application shortcuts | Needs design |
| [F-003](#f-003) | Drag-sort selected items in the editor | Deferred |
| [F-004](#f-004) | Future content/plugin extension support | Deferred |
| [F-005](#f-005) | Possible whole-panel widget | Deferred |
| [F-006](#f-006) | Application actions and recent documents | Implemented — needs verification (actions); Planned (documents) |
| [F-007](#f-007) | Recent / Frequent activity source | Implemented — needs verification |
| [F-008](#f-008) | KIO virtual and remote folders | Needs design |
| [F-009](#f-009) | Custom launch commands and terminal entries | Needs design |
| [F-010](#f-010) | Grouped Most frequent / Most recently used activity stacks | Needs design |
| [F-011](#f-011) | Menu column wrapping (True Launch Bar style) | Needs design |
| [F-012](#f-012) | Distribution packaging (OBS) and KDE Store listing | Planned |
| [F-013](#f-013) | Cross-machine profile portability | Implemented — needs verification |
| [F-014](#f-014) | Direct panel launchers alongside stacks | Planned within F-015 |
| [F-015](#f-015) | Stack Groups | In progress — shared config editor built; desktop verification next |
| [F-016](#f-016) | Shared stack settings editor for both widgets | Implemented — needs verification |
| [M-001](#m-001) | Clean source-control checkpoint | Verified |
| [M-002](#m-002) | CI/release pipeline hardening follow-ups | In progress |

<a id="f-001"></a>
## F-001 — Unobtrusive, delayed tooltips

Requested October 5, 2026. Status: **Implemented — needs verification**.

Acceptance criteria:

- Names in icons-only mode appear outside or away from menu rows, without obscuring
  other items; account for screen edges.
- Show after the pointer or keyboard selection pauses. Rapid traversal should not
  flash a tooltip for each row; cancel pending display when selection changes.
- Show tooltips in both display modes (updated user preference). Application
  descriptions appear when supplied by the desktop entry. Live Folder always shows filenames.
- Keep tooltip timing separate from the existing panel/submenu opening delay.
- Preserve mouse/keyboard handoff and menu dismissal behavior at each depth.

Implemented a fixed 700 ms selection delay, independent of menu opening. All
root rows use small, input-transparent Plasma tooltip windows beside the popup; native submenus use Qt menu tooltips. Folder previews suppress the parent tooltip while open.
A configurable delay remains a possible refinement.
Desktop placement and input verification are still required.
Context: [navigation contract](STACK_ENTRY_MODEL.md#navigation-contract) and
[historical information display](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#8-appearance-and-information-display).

<a id="f-002"></a>
## F-002 — Folders alongside selected application shortcuts

Requested October 5, 2026. Status: **Needs design**.

October 6 clarification: the user's main everyday-launcher goal is direct panel
shortcuts without opening a popup; that is tracked separately in [F-014](#f-014).
This entry retains the earlier request for folders *inside* a stack, rather than
making that a prerequisite for direct launchers or custom commands.

Allow a Selected Applications stack to include a folder entry alongside application
shortcuts. A folder should reuse the same preview, Right/Left, hover, and focus-return
behavior as Live Folder. Navigation should depend on an entry having children, not
on inventing a new set of key rules for each source.

Open decisions: persisted mixed-item schema and migration from desktop-ID lists;
editor addition/order/labels/icons; per-folder filtering; menu export versioning;
removing a configured folder reference versus trashing files inside it. Removing
an entry must not silently delete the referenced folder.

Current boundary: [entry model](STACK_ENTRY_MODEL.md#sources-and-renderers). Current
Selected Applications accepts applications only; this tracker entry does not change that.

<a id="f-003"></a>
## F-003 — Drag-sort editor items

Status: **In progress — top-level group ordering desktop-accepted**.
Drag handles reorder whole launchers and stacks, retaining Up/Down controls and
Apply/Cancel semantics. The next increment adds dragging applications and
separators within Selected Applications stacks. See the
[test checklist](STACK_GROUPS.md#drag-panel-items-into-order--desktop-test).

<a id="f-004"></a>
## F-004 — Future extension support

Earlier user intent; status: **Deferred**. Preserve room for content providers or
plugins, without claiming the current internal entry structure is a public SDK.
No API, trust model, packaging, or compatibility promise has been designed.
See [current entry boundaries](STACK_ENTRY_MODEL.md) and the
[historical SDK distinction](TRUE_LAUNCH_BAR_WINDOWS_FEATURE_REFERENCE.md#11-published-source-sdk-and-application-boundary).

<a id="f-005"></a>
## F-005 — Possible whole-panel widget

Earlier user interest; status: **Deferred**. Explore a larger widget that could
host multiple stacks and individual launchers. No decision to replace or extend
Icons Only Task Manager has been made. Current work remains individual stack widgets;
this idea does not authorize a task-manager rewrite.

<a id="m-001"></a>
## M-001 — Clean source-control checkpoint

Status: **Verified** for the local October 5 source checkpoint. Generated build
files were removed from the Git index, not deleted from disk. Ignore rules cover
build/test output, local installation staging, and Python caches. The checkpoint
includes source, regression tests, documentation, and the supplied manual.
Remote publication is a separate Git operation and is not implied by this status.
See [current repository/testing status](TESTING_AND_STATUS.md).

## Completed work and ongoing verification

The [code-review follow-up](TESTING_AND_STATUS.md#october-code-review-follow-up) owns
R1–R7 status. The [desktop results](TESTING_AND_STATUS.md#desktop-checks-reported-by-the-user)
own the completed navigation, dismissal, sizing, and Trash verification record.
The [remaining verification list](TESTING_AND_STATUS.md#still-to-verify) owns untested
combinations. Do not duplicate those checklists here. New implementation requests
receive tracker IDs; additional test evidence belongs in that existing record.

<a id="f-006"></a>
## F-006 — Application actions and recent documents

Application-provided desktop actions: **Implemented — needs verification**.
Selected Applications and category stacks expose visible desktop-entry actions
in their right-click/keyboard context menus. Only selected shortcuts offer Remove.
Actions launch through KDE's application launcher; Live Folder is unchanged.

Recent documents: **Planned**, separate from desktop actions. Determine the KDE
history source and respect its privacy settings before implementing this part.

<a id="f-007"></a>
## F-007 — Recent / Frequent activity source

Status: **Implemented — needs verification** (applications). Use KDE's Activities Stats API rather than maintaining a
separate usage database. Initial implementation targets applications, ranked by
recent use or frequency, with a configurable limit, optional desktop categories,
and current/all Activities scope. Apply the category filter before the final item
limit; preserve ranking and deduplicate desktop IDs.

Reuse application entries, icons, activation, keyboard navigation, and desktop
actions. Do not offer Remove from this stack for computed membership. Refresh
on opening while keeping an open menu stable. Empty/unavailable history needs
an explanatory state; never enable tracking or change KDE privacy settings.
Exports contain query settings, not usage history. Regression coverage should
include filtering/ranking, unavailable apps, deduplication, limits, and old-profile
defaults. KDE service integration additionally needs desktop verification.

Documents are a follow-up within this source: define document type/application
filters separately from desktop application categories. Recent-document context
menus must not inherit Live Folder deletion capabilities by accident.

Build prerequisite: PlasmaActivities and PlasmaActivitiesStats development
packages (Fedora: plasma-activities-devel and plasma-activities-stats-devel).

<a id="f-008"></a>
## F-008 — KIO virtual and remote folders

Status: **Needs design**. Investigate asynchronous KIO listing for virtual and
remote URLs (timeline, tags, remote, SMB), contingent on installed workers and
services. Current Live Folder remains local-only. Preserve URLs throughout
listing, activation, configuration, and profile transport. First scope should be
browsing/opening, with cancellation, authentication, and offline handling; file
operations require capability checks rather than assuming Trash is supported.

<a id="f-009"></a>
## F-009 — Custom launch commands and terminal entries

Status: **Needs design**. Allow per-entry launch customization, especially command
arguments, without modifying the system application desktop file. Add standalone
command entries with name, icon, executable, arguments, working directory, and
optional terminal execution. Separate direct executable/arguments from explicit
shell-script execution. Investigate preferred-terminal integration and optional
keep-open behavior. Preserve installed-app launch wrappers/field codes rather than
blindly concatenating text to desktop Exec lines.

October 6 clarification: keep this feature independent of [F-002](#f-002).
Application selection should remain search-based: choose an installed application,
then optionally configure arguments for that entry without editing its installed
`.desktop` file. Distinct entries may reference the same application with different
arguments, names, or icons (for example, VS Code opening two different projects).

A second part is a library of common commands, which may have no installed
application identity. Design this explicitly as command entries rather than
pretending every command is an installed application. Executable/argument lists,
working directory, terminal behavior, and explicit shell execution are separate
settings; the exact editor and first supported subset remain to be agreed.

Share launch definitions with [direct panel launchers](#f-014) so the same action
can eventually be used in a popup or directly on the panel. Coordinate entry
identity/schema when useful, but do not require mixed-folder support first.
Include Apply/Cancel and profile migration/export behavior in the design; profiles
store commands, not arbitrary bundled executables. Importing must not run commands.

<a id="f-010"></a>
## F-010 — Grouped Most frequent / Most recently used activity stacks

Requested October 6, 2026. Status: **Needs design**.

Split the activity stack into two ordered groups — Most frequently used and Most
recently used — with a titled separator between them, reusing the labeled-separator
rendering already used by Selected Applications (separator rendering is
source-agnostic; any entry with `isSeparator` renders). Today [F-007](#f-007)
makes one mutually exclusive query (`RecentlyUsedFirst` or `HighScoredFirst`,
chosen by the order setting) and overwrites the entry list per refresh, so this
needs a dual-list producer: two queries and a synthetic labeled separator entry
between the concatenated groups.

Open decisions: duplicate applications across both groups (show twice, or does
one group win?); which group is first; per-group limits versus splitting
`activityLimit`; whether grouping becomes a third ordering option or replaces an
existing one; refresh stability while a menu is open (F-007 constraint).
Regression coverage should mirror F-007's: filtering, unavailable apps,
deduplication, and limits.

<a id="f-011"></a>
## F-011 — Menu column wrapping (True Launch Bar style)

Requested October 6, 2026. Status: **Needs design**.

When a popup menu would grow taller than the screen, wrap entries into a second
side-by-side column instead of forcing scrolling, keeping the whole menu visible —
True Launch Bar behavior. The root menu is a ScrollView over a ColumnLayout plus
Repeater with a height clamp and fixed width (`main.qml`); wrapping requires
chunking entries across columns, syncing popup width as well as height, and
updating the manual keyboard navigation and content handling that assumes one
column. The folder root menu uses a ListView and can chunk similarly. Native
cascades are C++ QMenu popups; Qt has no built-in multi-column menus, so that path
needs a custom popup design — decide whether cascades wrap at all in the first
scope. Separators are entries in the same flat array; a column break must not
orphan a separator at a column edge. Column count, height budget, and screen-edge
placement need desktop verification.

<a id="f-012"></a>
## F-012 — Distribution packaging (OBS) and KDE Store listing

Requested October 6, 2026. Status: **Planned** (direction agreed).

Build distribution packages via the Open Build Service so Fedora, openSUSE,
Debian, and Ubuntu users install a native build of the compiled plugin through
their own package managers, built per-distro against each distribution's real
Qt6/KF6 stack from the tagged source tarballs the release pipeline already
publishes. A KDE Store listing page is for discovery and ratings only: "Get New
Widgets" cannot install a compiled C++ plugin, and no store upload API exists
(October 6 research — store updates are manual web uploads). COPR (Fedora) and
AUR (Arch) are lighter single-distro alternatives if full OBS proves heavy.
First scope: one Fedora and one Debian/Ubuntu repository publishing the plugin
and widget files from release tags.

<a id="m-002"></a>
## M-002 — CI/release pipeline hardening follow-ups

Requested October 6, 2026 (review follow-up). Status: **In progress** (pinning
and permissions done; release checklist planned).

Remaining reviewer recommendations after the October 6 pipeline work (PRs
#3–#9; regression tests are already wired into CI, and runner resolution and
absolute build directories are done):

- Pin `actions/checkout` and `softprops/action-gh-release` to reviewed commit
  SHAs — **done October 6, 2026** (checkout v4.4.0, gh-release v2.6.2; version
  comments kept for Dependabot updates).
- Declare `permissions: contents: read` on `ci.yml` — **done October 6, 2026**
  (least-privilege for the build job; `release.yml` already scopes its write).
- Add a maintainer release checklist to [Deployment](DEPLOYMENT.md): bump
  `CMakeLists.txt` and `package/metadata.json` versions together, confirm green
  CI on `main`, tag the merged commit, push the tag, then verify the three
  release assets. — **Planned**.


<a id="f-013"></a>
## F-013 — Cross-machine profile portability

Status: **Implemented — needs verification** (October 6, 2026).

Standard user folders relocate through Qt's configured locations in version 5
archives; other absolute locations remain explicit. Missing folders are reported
on import. Custom images remain bundled, desktop IDs and separator order are
preserved, and the shared QML icon renderer falls back from unavailable custom artwork to
the app’s default icon, then to a generic application icon.
See [profile format and import behavior](DEPLOYMENT.md#portable-menu-profiles).

Import/export desktop testing was reported successful by the user.
Cross-machine checks remaining: export a Documents subfolder and import under another
user with a different Documents location; inspect the resolved path before Apply.
Check an unavailable theme icon in both panel and menu. Native/Flatpak application
ID mapping remains manual; no guessed substitutions are made. Existing Qt6/KF6/
Plasma6 builds and Fedora CI do not establish a cross-distribution minimum version.


<a id="f-014"></a>
## F-014 — Direct panel launchers alongside stacks

Clarified October 6, 2026. Status: **Planned within [F-015](#f-015)**.

Frequently used shortcuts should launch directly from the panel without opening
a stack popup. The user wants to keep Icons Only Task Manager for running-window
management while using TLBStacks for launching. This is distinct from folders
inside a Selected Applications menu ([F-002](#f-002)) and does not require the
whole-panel widget idea ([F-005](#f-005)).

Earlier alternative, not selected: an explicit single-launcher mode on an
individual widget instance, configured through application search with a name and
icon. Click or keyboard activation launches; hover offers a tooltip, not a menu.
Users arrange launcher instances alongside stack instances using Plasma's panel
editor. Do not automatically change a one-item stack into a launcher: its intended
interaction must remain explicit.

Share launch behavior with [F-009](#f-009) when arguments and custom commands are
introduced. A multi-launcher strip could follow if arranging separate instances
proves cumbersome; no task-manager replacement or window-grouping behavior is
part of this proposal.


<a id="f-015"></a>
## F-015 — Stack Groups

Status: **In progress — launcher Appearance accepted**. The user selected an optional collection widget
containing stacks and direct launchers, without task management. Preserve existing
independent stack widgets and individual stack import/export. This is the scoped
container direction discussed under F-005; it does not authorize a panel replacement.
Direct launchers from F-014 belong here. F-009 remains independently scoped.

Use one configuration window with an ordered item list and settings for the selected
item, whole-window Apply/Cancel, Add stack/application, ordering and removal. Import
an individual stack; export one stack or the group. Future item context actions can
open this editor with the relevant item selected. Do not duplicate stack navigation
and rendering implementations for the container.

October 7, 2026: the shared configuration editor is merged, and its polish pass
has desktop acceptance. Panel right-click item editing is dropped for now; leave
its parked stash untouched. Direct-launcher label/icon overrides are implemented
and accepted by the user, with Reset explicitly confirmed. Whole-group archive
transport is covered by automated tests.
See [the current checklist](STACK_GROUPS.md#direct-launcher-appearance).
Selectable child rows for icon editing are desktop-accepted. Top-level drag
ordering is desktop-accepted; inherited defaults and member dragging remain
future increments.

The six accepted checkpoints and the exact resume/test instructions are maintained
in [Stack Groups](STACK_GROUPS.md). Complete and desktop-test each checkpoint before
starting the next; keep changes small enough to resume across usage-limit pauses.

<a id="f-016"></a>
## F-016 — Shared stack settings editor for both widgets

Requested October 7, 2026 (from the
[configuration editor redesign](CONFIGURATION_DESIGN.md)). Status:
**Implemented — needs verification** on the `shared-stack-editor` branch;
desktop verification pending and nothing merged.

One `StackSettingsEditor` (kind segments for Selected / Live folder / Categories /
Recent, Contents/Appearance tabs, all four source pages, per-application and stack
icon Choose…/Image…/Reset; Image… and member Reset go through the launcher's
`manageIcon` operation, Choose… picks from the theme dialog directly) serves
both the standalone widget and the group. It edits plain data and emits partial
changes; the standalone host persists into its existing `cfg_*` keys and the group
host into `General/items`, so schemas, Apply/Cancel staging and import/export are
unchanged. Supporting pieces: a search-on-add `AppPickerDialog`, a `CategoryChipBar`
chip cloud with host-owned selection, and shared separator helpers
(`StackMembers.js`). The group host adds a preview strip, an expandable item tree
(summary-only child rows), a breadcrumb and a resizable split view; the launcher
page swaps applications via `GroupItems.replaceLauncher`.

Explicitly deferred: inherited group defaults (`-1` values), a group-level panel
icon config key, launcher custom label/icon overrides, selectable tree child rows
and drag-and-drop reordering (see [F-003](#f-003) for reordering scope). The
group-button right-click/hover fix (design step 1) is separate uncommitted work in
the main checkout; when it lands, its groupSelection consumption block and test
must be re-wired into the rebuilt group host layout. The shipped structure and the
manual verification checklist are recorded in
[Stack Groups](STACK_GROUPS.md#shared-stack-editor-rebuild-branch-shared-stack-editor).

# Feature and follow-up tracker

[Project guide](README.md) · [Current model](STACK_ENTRY_MODEL.md) · [Verification](TESTING_AND_STATUS.md)

**Updated:** October 5, 2026. This is the authoritative list of requested future
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
| [M-001](#m-001) | Clean source-control checkpoint | Verified |

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

Earlier user request; status: **Deferred**. Add drag reordering while retaining
accessible Up/Down controls and existing Apply/Cancel semantics. Mixed-item design
may affect the editor, so coordinate with [F-002](#f-002). Current reordering is documented
in [Deployment](DEPLOYMENT.md).

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

## F-006 — Application actions and recent documents

Application-provided desktop actions: **Implemented — needs verification**.
Selected Applications and category stacks expose visible desktop-entry actions
in their right-click/keyboard context menus. Only selected shortcuts offer Remove.
Actions launch through KDE's application launcher; Live Folder is unchanged.

Recent documents: **Planned**, separate from desktop actions. Determine the KDE
history source and respect its privacy settings before implementing this part.

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

## F-008 — KIO virtual and remote folders

Status: **Needs design**. Investigate asynchronous KIO listing for virtual and
remote URLs (timeline, tags, remote, SMB), contingent on installed workers and
services. Current Live Folder remains local-only. Preserve URLs throughout
listing, activation, configuration, and profile transport. First scope should be
browsing/opening, with cancellation, authentication, and offline handling; file
operations require capability checks rather than assuming Trash is supported.

## F-009 — Custom launch commands and terminal entries

Status: **Needs design**. Allow per-entry launch customization, especially command
arguments, without modifying the system application desktop file. Add standalone
command entries with name, icon, executable, arguments, working directory, and
optional terminal execution. Separate direct executable/arguments from explicit
shell-script execution. Investigate preferred-terminal integration and optional
keep-open behavior. Preserve installed-app launch wrappers/field codes rather than
blindly concatenating text to desktop Exec lines.

Coordinate stable per-entry identity and duplicate app variants with F-002's
mixed-item model (for example, two VS Code shortcuts opening different projects).
Include Apply/Cancel and profile migration/export behavior in the design; profiles
store commands, not arbitrary bundled executables. Importing must not run commands.

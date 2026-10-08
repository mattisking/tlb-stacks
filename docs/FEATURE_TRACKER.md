# Feature and follow-up tracker

[Project guide](README.md) · [Current model](STACK_ENTRY_MODEL.md) · [Verification](TESTING_AND_STATUS.md) · [Group checkpoints](STACK_GROUPS.md)

**Reviewed:** October 8, 2026. This tracks requested work, not a promise to implement
all historical ideas. IDs and anchors are retained for existing links. Completed
features belong in the implementation docs; test gaps belong in the verification
record. Desktop acceptance does not mean every optional test combination was run.

## Current queue

| ID | Request | Current status |
|---|---|---|
| [F-003](#f-003) | Drag ordering and editor controls | Dragging accepted; selected-row arrow polish awaiting desktop test |
| [F-015](#f-015) | Stack Groups | Delivered increments accepted; panel icon defaults await desktop testing |
| [F-009](#f-009) | App arguments and custom/terminal commands | Custom executables implemented; desktop test pending |
| [M-002](#m-002) | Release maintenance | CI fixed; maintainer release checklist still planned |
| [F-002](#f-002) | Original launcher/mixed-folder request | Superseded by F-015; mixed folders deferred |
| [F-006](#f-006) | Application actions and recent documents | Actions implemented; documents planned |
| [F-007](#f-007) | Recent/Frequent source | Application source implemented; documents a follow-up |
| [F-010](#f-010) | Combined Frequent/Recent sections | Needs design |
| [F-011](#f-011) | Menu column wrapping | Needs design |
| [F-008](#f-008) | KIO virtual/remote folders | Needs design |
| [F-012](#f-012) | Distribution repositories and KDE Store listing | Planned |
| [F-013](#f-013) | Cross-machine portability | Implemented; cross-machine verification remains |

Completed or deliberately set aside: [tooltips](#f-001), [plugin support](#f-004),
[whole-panel replacement](#f-005), [direct launchers](#f-014),
[shared editor](#f-016), and [source-control cleanup](#m-001).

<a id="f-001"></a>
## F-001 — Unobtrusive, delayed tooltips

**Implemented; desktop behavior accepted.** Tooltips appear beside the menu after
pausing, with application descriptions when available. They work in both display
modes; Live Folder uses icons and filenames. Tooltip delay is separate from popup
opening delay. A configurable tooltip delay is only a possible refinement, not an
active commitment. Screen-edge and input combinations remain regression checks.
See the [navigation contract](STACK_ENTRY_MODEL.md#navigation-contract).

<a id="f-002"></a>
## F-002 — Folders alongside selected application shortcuts

**Superseded by F-015 for the chosen launcher direction.** Folders *inside* a
Selected Applications menu remain only a deferred idea, not an active commitment. The everyday direct-panel-shortcut request was split out and
has been delivered through [Stack Groups](#f-015); do not reopen that decision here.

Mixed entries need a persistence/migration design, folder addition and filtering,
consistent submenu navigation, and archive compatibility. Removing a configured
folder reference must not delete the folder. Current Selected Applications holds
applications and separators, not folder entries. See [entry boundaries](STACK_ENTRY_MODEL.md).

<a id="f-003"></a>
## F-003 — Drag ordering and editor controls

**Dragging implemented and desktop-accepted.** Both whole group items and
applications/separators within stacks can be dragged. Shared gesture handling
preserves Apply/Cancel, custom icons, cancellation, and edge scrolling.

Current visual polish: Up/Down controls appear only on the selected or
keyboard-focused Contents row, with space reserved so other controls do not move.
This polish awaits desktop acceptance; dragging itself is complete.
See [the member checkpoint](STACK_GROUPS.md#drag-selected-applications-and-separators--desktop-test).

<a id="f-004"></a>
## F-004 — Future content/plugin extension support

**Deferred.** Still a user interest, but no SDK, trust model, packaging contract,
or compatibility promise has been designed. The common entry description is an
internal foundation, not a public plugin API. See [entry model](STACK_ENTRY_MODEL.md).

<a id="f-005"></a>
## F-005 — Possible whole-panel widget

**Original launcher-container direction superseded by F-015.** Stack Groups
provides the chosen collection of stacks and direct launchers, alongside the
existing standalone widget. A separate competing launcher container is not queued.

A full panel/task-manager replacement remains **deferred**, not part of current
scope. Extending or forking Icons Only Task Manager was explored, not selected.

<a id="f-006"></a>
## F-006 — Application actions and recent documents

**Desktop actions implemented.** Application-provided actions are exposed by app
menus across selected, category, and activity sources when the desktop entry offers
them. Only selected membership offers Remove. An app with no actions need not show
any; this is not an incomplete implementation.

**Recent documents planned**, separate from desktop actions. Determine the KDE
history source and respect privacy settings. Coordinate with F-007 rather than
building two separate document-history implementations.

<a id="f-007"></a>
## F-007 — Recent / Frequent activity source

**Application source implemented; desktop feedback accepted its improved behavior.**
Uses KActivities Stats, with recent/frequent ordering, limits, category filtering,
and Activity scope. Configuration exports query settings, not history. Membership
is computed, so it does not offer Remove. Keep open-menu results stable and do not
change KDE tracking/privacy preferences.

Documents remain a follow-up shared with F-006. Define document filters separately
from application categories; do not inherit Live Folder deletion actions. Service
availability and unusual history combinations remain verification work.

<a id="f-008"></a>
## F-008 — KIO virtual and remote folders

**Needs design.** Current Live Folder is local-only. Explore asynchronous listing
for timeline, tags, remote and SMB URLs with installed KIO workers. Start with
browsing/opening, cancellation, authentication and offline handling. File actions
must follow backend capabilities; do not assume remote Trash support.

<a id="f-009"></a>
## F-009 — Custom launch commands and terminal entries

**First increment implemented, awaiting desktop acceptance; independent of mixed folders.**
Selected Contents supports custom executable launchers with a name, absolute path,
quoted arguments, and the existing icon controls. The group Add menu also supports
direct panel custom launchers using the same editor. Commands execute directly without
a shell; paths remain explicit in archives. See [custom launchers](DEPLOYMENT.md#custom-executable-launchers).

Remaining scope:

- Select an installed application through search, then optionally supply arguments
  without editing its installed desktop file. Multiple entries may target the same
  application with different arguments, labels, or icons.
- Extend custom entries with working directory and optional terminal behavior. Explicit shell scripts and direct
  execution are separate choices; preferred-terminal/keep-open behavior needs design.

Share definitions between direct panel launchers and popup entries. Preserve desktop
launch wrappers/field codes rather than concatenating text onto Exec lines. Design
identity, Apply/Cancel and archive migration together. Importing a profile must not
execute commands; profiles do not bundle arbitrary executables.

<a id="f-010"></a>
## F-010 — Combined Frequent / Recent sections

**Needs design.** One activity menu containing two titled sections, not the already
implemented choice between recent and frequent sorting. Decide ordering, per-section
limits, duplicate handling and refresh stability. Reuse existing separator rendering
and activity queries; keep this separate from the completed basic activity source.

<a id="f-011"></a>
## F-011 — Menu column wrapping

**Needs design.** Wrap tall menus into side-by-side columns instead of scrolling.
Requires screen-aware sizing, keyboard navigation, separator placement, and a
specific decision about whether native folder cascades participate in the first
scope. It is not ordinary horizontal scrolling.

<a id="f-012"></a>
## F-012 — Distribution packaging and KDE Store listing

**Planned.** Release assets and packaging groundwork exist; publishing distribution
repositories is separate work. Agreed direction: investigate Open Build Service,
initially Fedora and Debian/Ubuntu builds against their own Qt/KF versions. COPR/AUR
remain alternatives, not additional simultaneous commitments. A KDE Store listing
would provide discovery; the compiled plugin still needs distribution installation.
Recheck service requirements when this work starts.

<a id="f-013"></a>
## F-013 — Cross-machine profile portability

**Implemented; import/export desktop testing accepted.** Standard user-folder
references relocate using Qt's configured directories; custom images travel with
profiles. Missing overrides fall back to the app icon, then a generic icon.

Remaining verification: import on a different account with a different Documents
location, inspect missing-folder handling and unavailable theme icons. Native versus
Flatpak desktop-ID mapping remains manual; do not infer substitutions. Cross-distro
compatibility is not established by Fedora-only testing.
See [portable profiles](DEPLOYMENT.md#portable-menu-profiles).

<a id="f-014"></a>
## F-014 — Direct panel launchers alongside stacks

**Delivered within F-015; no separate implementation pending.** Stack Groups hosts
search-added application launchers alongside popup stacks, with custom labels/icons.
Icons Only Task Manager remains responsible for running windows.

The alternative of one standalone widget instance per direct launcher was not
selected and is not queued. Argument customization belongs to F-009.

<a id="f-015"></a>
## F-015 — Stack Groups

**Delivered increments desktop-accepted; experimental widget remains opt-in.**
Includes direct launchers, all four stack sources, ordering, shared settings,
individual-stack/group import/export, launcher appearance, member icon editing,
and dragging. See [checkpoints and remaining test combinations](STACK_GROUPS.md).

**Implemented, awaiting desktop acceptance:** a group panel icon-size default with
per-item overrides for stacks, applications and custom launchers. Compact automatic
remains the default; existing explicit sizes are preserved. Group archives retain
these choices. Broader inheritance (such as hover delay and popup appearance)
remains planned. Prototype `-1` values are not an approved schema.

**Dropped:** panel right-click “Configure this item” and the transient groupSelection
handoff. Edit through the full group editor. The old stash must stay parked; it is
not unfinished work to restore. No task-manager replacement is implied.

<a id="f-016"></a>
## F-016 — Shared stack settings editor

**Merged and desktop-accepted.** One StackSettingsEditor serves standalone and
group widgets, with Contents/Appearance, all sources, category search, managed
custom icons, and profile controls. Hosts keep their existing persistence contracts.
The group adds its preview, tree, breadcrumb and split view. Child app rows are
selectable for icon editing. Earlier notes calling this an unmerged branch or
requiring the right-click handoff are obsolete.

Future inheritance belongs to F-015; current arrow polish belongs to F-003.
See [configuration design](CONFIGURATION_DESIGN.md).

<a id="m-001"></a>
## M-001 — Clean source-control checkpoint

**Completed.** Generated build/test files are ignored, and accepted increments are
committed/pushed to main. This historical cleanup is not an ongoing feature.

<a id="m-002"></a>
## M-002 — CI/release maintenance

**Partly complete.** Action SHA pinning, scoped permissions, runner resolution,
absolute build directories and release regression tests are in place. Missing KDE
QML runtime dependencies were fixed in both workflows; see the
[successful CI repair](TESTING_AND_STATUS.md#ci-qml-runtime-dependencies).

**Still planned:** a maintainer release checklist in Deployment: update project and
both widget metadata versions together, confirm green CI, tag the merged commit,
push the tag and verify release assets. This does not imply a release is authorized.

## Verification, not new features

[Testing and status](TESTING_AND_STATUS.md) owns review follow-ups and remaining
manual checks. Optional vertical-panel, screen-edge, grouped-cascade, and
cross-machine combinations should not reopen features already accepted in normal
use. Record new failures as bugs with a reproducible case.

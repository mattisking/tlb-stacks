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

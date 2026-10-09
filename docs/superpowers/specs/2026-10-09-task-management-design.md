# TLBStacks Task Management — Design

- **Date:** 2026-10-09
- **Status:** Phase 1 approved in chat (placement/ownership model, click matrix, auto-append zone, plumbing, config, error handling, testing). Written for spec review.
- **Scope owner:** running-window awareness for the group widget and shared delegates; turns TLBStacks into a functional replacement for the Icons-Only Task Manager.

## Goal

TLBStacks stops being a pure launcher and becomes a task-aware panel widget:

1. **Existing `application` items come alive.** A panel app button whose app is running becomes a live task button — active-window highlight, click-to-activate/minimize toggle, no accidental new instances on plain click.
2. **Multi-window grouping.** All windows of one app stay on that app's button; clicks/scroll cycle through them.
3. **Auto-append.** Windows whose app appears nowhere in the group appear as extra icon buttons after the configured items, and vanish when closed.

Success criteria: with the stock Icons-Only Task Manager removed from the panel, a user can see every running window (as a live button or a popup entry with running state), switch windows, launch new instances (middle-click), and minimize via click — without any window being invisible.

## Non-goals (deferred phases)

- Attention ("demands attention") flashing/badges — later phase.
- Task context menus (close window, move to desktop, minimize/maximize menu items) — later phase.
- Hover window previews / PipeWire thumbnails — explicitly deferred; hardest piece.
- Pin/unpin context-menu sync, drag-to-pin from the appended zone, drag reordering of appended tasks.
- Virtual desktop / activity / screen filtering of tasks.
- Any change to `GroupItems.js` persistence format (appended tasks are live-only, never persisted).

## Grounded facts (verified 2026-10-09)

- **No task code exists in the repo.** README and `docs/FEATURE_TRACKER.md` explicitly scope TLBStacks to launcher duties; the only `winId()` uses are for native QMenu parenting (`src/launcher.cpp`).
- **Task backend availability:** the QML plugin ships with plasma-workspace on every Plasma 6 install. Imports (verified against plasma-desktop/plasma-workspace source):
  - `import org.kde.taskmanager 0.1 as TaskManager` — `TasksModel`, `LauncherTasksModel`, `TaskTools`. **Still `0.1` in Plasma 6** — `1.0` does not resolve (a claim from a third-party AI conversation that is wrong).
  - `import org.kde.plasma.private.taskmanager 0.1` — `TaskManagerBackend`, `SmartLauncherItem` (not needed in phase 1).
- **TasksModel phase-1 API surface:** `groupMode` (`GroupApplications`), roles `display`/`icon`/`isActive`/`isMinimized`/`isWindow`/`isLauncher`/`LauncherUrl`/`AppId`/`IsGroupParent`, methods `requestActivate(index)`, `requestNewInstance(index)`, `requestToggleMinimized(index)`. Wayland activation from third-party plasmoids works — KWin grants plasmoids privileged activation via plasma-window-management.
- **License:** libtaskmanager is LGPL-2.0-or-later; runtime QML import imposes no licensing obligation on this repo's code.
- **Private-API caveat:** `org.kde.taskmanager` is the stable-ish library surface; `org.kde.plasma.private.taskmanager` is explicitly private. Phase 1 uses only the former. Expect possible maintenance at major Plasma upgrades; document the import in `docs/DEBUGGING.md` conventions.
- **Reuse surface in this repo:** the app-item delegate (`package/contents/ui/ApplicationMenu.qml:73-198`, `PlasmaComponents.ItemDelegate` + `ApplicationIcon` + label) and the group panel button (`package-group/contents/ui/main.qml:178-277`, `PlasmaComponents.ToolButton` + `ApplicationIcon`) are the two renderings that gain task behavior.

## Design

### Approach (chosen: "TasksModel as state source")

The group's JSON item list (`GroupItems.js`) **remains the view model and source of truth**. A shared `TasksModel` acts only as a live window database. Matching (desktop ID ↔ window task) decides whether each rendered item behaves as a launcher or a live task button.

Rejected alternative: feed group items into `TasksModel.launcherList` with `launchInPlace` and render the model directly (upstream Icons-Only architecture). It cannot represent `stack`/`command`/separator items, and manual-order sync between the model and the JSON would be bidirectional state duplication. Upstream's C++ still does all window plumbing either way; we choose to keep our own model as the render source.

### Placement & ownership model

- **Rule:** any `application` item — panel-direct or stack-embedded — takes on live task behavior *where it is rendered*. A stack-embedded app does **not** auto-append; it is pinned, just nested. Its running state surfaces inside the popup (running dot, activate-on-click) and as a subtle "has running members" indicator on the stack's panel button.
- **Ownership:** a running app binds to one owner button — the first/most-specific placement in the group (panel-direct item wins over stack-embedded). Other renderings of the same app mirror state read-only.
- **Auto-append zone** (below) shows only windows whose app appears nowhere in the group.

### Click & grouping matrix

**Panel button, single window:**

| Input | Not running | Running, not focused | Focused |
|---|---|---|---|
| Left-click | Launch | Activate / unminimize | Minimize |
| Middle-click | Launch | New instance | New instance |

**Panel button, grouped windows (multiple windows, one app):**

| Input | Behavior |
|---|---|
| Left-click | Activate the most-recently-used window (restoring if minimized); if focused already, cycle to the next window (knob to revisit after feel-testing; alternative: chooser popup) |
| Scroll wheel | Step forward/backward through the group's windows |
| Middle-click | New instance |

**Visual states:** active window → highlighted button; running, not active → small dot on the icon; multiple windows → count badge.

**Popup entries (stack menus, app menus):** click activates/toggles the window; middle-click launches new; running dot + count mirrored; no scroll cycling in menus.

All window manipulation routes through `TasksModel::requestActivate` / `requestNewInstance` / `requestToggleMinimized` — no direct KWindowSystem calls from this repo; Wayland/X11 differences stay KDE's problem.

### Auto-append zone

- Rendered after the last configured group item; same visual language as app ToolButtons.
- Order: `TasksModel` order (launch order, becoming most-recently-used after activations). No user reordering in phase 1.
- Exclusions: any task whose app matches an item anywhere in the group (direct or nested) — the ownership rule.
- Live-only: never written to `GroupItems.js`; closing the window removes the button.

### Plumbing

- **QML owns the model.** The group instantiates `TaskManager.TasksModel { groupMode: TaskManager.TasksModel.GroupApplications }` in QML. No new CMake link dependency on plasma-workspace; no new required packages.
- **C++ owns matching.** New type in the existing `tlbstacksplugin` (working name `TaskIndex`): receives the `TasksModel` plus the group's current desktop-ID set (refreshed whenever `GroupItems` changes), exposes per-app state (`running`, `active`, `count`, `minimized`, model index of owner task/group) and the "unclaimed tasks" list for the append zone. C++ is where launcherUrl↔desktop-ID matching and role lookups live; QML stays declarative.
- **Graceful degradation:** no static `org.kde.taskmanager` import in `main.qml`. The feature lives in its own QML file loaded dynamically (component-create in try/catch). If the module is missing on a minimal install, the widget runs exactly as today, as a pure launcher.

### Config surface

- One new group config key: `taskTrackingEnabled` (default `true`). No other keys in phase 1.
- Standalone widget: benefits via the shared delegate (popup running dots, activate-on-click, "running member" indicator on its stack button); no standalone-specific config.

## Error handling

- Missing `org.kde.taskmanager` module → dynamic load fails → feature silently disabled (see Plumbing).
- `command` items (`tlbstacks-command:*`) never match windows — launch-only by design.
- Windows with no resolvable desktop entry: still auto-append as generic task buttons (icon/title from window roles).
- Zero windows running: no append zone; every app item behaves exactly as today. Feature invisible when idle.

## Testing

- **Unit:** new suite for `TaskIndex` against a mock tasks model (roles, ownership rule, append-zone filtering, desktop-ID matching), wired into `scripts/ci-run.sh` alongside existing suites (env conventions per `docs/TESTING_AND_STATUS.md`).
- **Manual feel-test checklist** (the knobs the user wants to try): launch → activate → minimize → grouped cycling → scroll stepping → middle-click new instance → append/unappend on launch/close → popup running dots. Verified on the dev environment of record (Fedora + Wayland) via the existing install flow.

## Future phases (candidates, in rough order)

1. Attention states (badge/flash) — cheap once live state flows to delegates.
2. Task context menus (close, minimize/maximize, move to desktop).
3. Drag-to-pin: drop an appended task into the group → becomes a persisted `application` item; drag reordering of appended tasks.
4. Virtual desktop / activity / screen filters (config keys, mirroring Icons-Only options).
5. Hover previews (PipeWire thumbnails) — highest effort, last.

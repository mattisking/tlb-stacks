# Task Management Phase 1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give TLBStacks running-window awareness so the group widget (plus shared popup delegates) functionally replaces the Icons-Only Task Manager.

**Architecture:** A shared `TasksModel` (from `org.kde.taskmanager 0.1`, created in QML) is a live window database only — group JSON items remain the view model and source of truth. A new C++ `TaskIndex` type does desktop-ID↔window matching and exposes per-app state plus an unclaimed-tasks append list; QML gains live click behavior via `TaskArea.qml`, loaded through a `Loader` so a missing taskmanager module degrades to pure-launcher mode.

**Tech Stack:** Qt6/QML, KF6, Plasma 6 plasmoid packaging, existing `tlbstacksplugin` QML module (`com.mattphilmon.tlbstacks`).

**Spec:** `docs/superpowers/specs/2026-10-09-task-management-design.md`

## Global Constraints

- No new CMake link dependencies: `TaskIndex` reads a generic `QAbstractItemModel` by role name and calls model actions via `QMetaObject::invokeMethod`. Never link plasma-workspace/libtaskmanager.
- `import org.kde.taskmanager 0.1` appears **only** inside `TaskArea.qml`. No `main.qml` (either package) may statically import any taskmanager module.
- `GroupItems.js` persistence format is untouched; appended tasks are live-only.
- Import is `0.1` — never `1.0` (does not resolve in Plasma 6).
- Test env (from `scripts/ci-run.sh:53`): `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH=<build>/qml`.
- Registration pattern (from `src/plugin.cpp:16-18`): `qmlRegisterType<TaskIndex>(uri, 1, 0, "TaskIndex")`.
- New shared QML files follow the existing pattern: live in `package/contents/ui/`, registered in `src/CMakeLists.txt` with `QT_QML_SKIP_CACHEGEN TRUE`.

## Review Focus

1. **Left-click launching a duplicate instance when the app is running** (activate returns false and caller falls back to launch): pinned by Task 2's `activate` tests — false only when zero rows match.
2. **`LauncherUrl` variants not matching → a pinned app also shows in the append zone**: pinned by Task 1 normalization tests (`applications:` scheme, `file:` path, bare path, `.desktop` suffix).
3. **Stale state after a window closes** (ghost running dot / ghost appended button): pinned by Task 1 revision tests (`rowsRemoved`, `rowsInserted`, `dataChanged`, `modelReset` all bump revision).
4. **Empty group / empty desktopIds** (pure-stack group, or `taskArea === null` after degraded load) must render and behave exactly as today: pinned by Task 4's QML tests with null mock and by Task 5's `ApplicationMenu` tests with `taskArea: null`.
5. **Missing `org.kde.taskmanager` module must not brick the widget**: `main.qml` has no static import; `TaskArea.qml` is instantiated only via `Loader`, error → `root.taskArea = null`. Verified by inspection in Task 3 and the manual checklist in Task 6. (Middle-click/wheel delivery is manual-checklist territory — QML test env cannot exercise panel mouse routing.)

---

### Task 1: `TaskIndex` — model watching, matching, `taskState`

**Files:**
- Create: `src/taskindex.h`, `src/taskindex.cpp`
- Create: `tests/task-index/CMakeLists.txt` (mirror `tests/native-menus/CMakeLists.txt` standalone-project pattern; build `task-index-test`)
- Create: `tests/task-index/mocktasksmodel.h` (QAbstractItemModel subclass, `setRoleNames` for the roles below, test-only invokables)
- Create: `tests/task-index/tst_taskindex.cpp`
- Modify: `src/plugin.cpp` (register type), `src/CMakeLists.txt` (add `taskindex.cpp`/`taskindex.h` to `SOURCES`)

**Interfaces:**
- Produces (later tasks rely on these exact signatures):
  - `Q_PROPERTY(QAbstractItemModel *model READ model WRITE setModel NOTIFY changed)`
  - `Q_PROPERTY(QStringList desktopIds READ desktopIds WRITE setDesktopIds NOTIFY changed)`
  - `Q_PROPERTY(int revision READ revision NOTIFY changed)` — bump on every model change and property swap; QML bindings reference it to refresh.
  - `Q_INVOKABLE QVariantMap taskState(const QString &desktopId) const` → `{running: bool, active: bool, minimized: bool, count: int, iconName: QString}` (defaults: all false / `0` / `"application-x-executable"` when not running).
- Role names read by name via `model->roleNames()`, verified against plasma-workspace source (`libtaskmanager/abstracttasksmodel.h`): `IsWindow`, `IsActive`, `IsMinimized`, `IsLauncher`, `IsGroupParent`, `LauncherUrl`, `AppId`, `display`, and `decoration` (Qt::DecorationRole — the icon role; there is no `icon` role). Missing roles are tolerated (treated absent).
- Test mock: `MockTasksModel` in `tests/task-index/mocktasksmodel.h` with invokable `setRows(QVariantList)` where each row map carries those role names as keys; also invokables `activateCalls`, `Q_INVOKABLE void requestActivate(const QModelIndex &)`, `requestToggleMinimized(const QModelIndex &)`, `requestNewInstance(const QModelIndex &)` recording calls (mocks the real `TasksModel` invokables for Task 2).

- [ ] **Step 1: Write failing tests** in `tests/task-index/tst_taskindex.cpp` for:
  1. `taskState("org.kde.konsole.desktop")` on empty model → `{running:false, active:false, minimized:false, count:0}`.
  2. One window row (`IsWindow:true`, `LauncherUrl:"file:///usr/share/applications/org.kde.konsole.desktop"`, `IsActive:true`) → `{running:true, active:true, count:1}`.
  3. Grouped app: two rows, one `IsGroupParent:true` group row + one window row → single `count` aggregate from group parent row (real TasksModel grouping is hierarchical — group parent rows with child window rows; `IsGroupParent` is the group-parent boolean) (`count` from window rows under it is Task 2's concern if needed; phase 1: match **group-parent and standalone-window rows only**, i.e. rows where `isWindow && !IsGroupParent`, or `IsGroupParent`).
  4. `LauncherUrl` normalization: `"applications:org.kde.konsole.desktop"`, `"file:///usr/share/applications/org.kde.konsole.desktop"`, `"/usr/share/applications/org.kde.konsole.desktop"`, and a URL with `.desktop` stripped-in-desktopIds form (`desktopIds` entries are desktop-file IDs like `org.kde.konsole.desktop`, exactly as `GroupItems.js:26` stores them) all match the same desktop ID. Rows with an empty/unresolvable `LauncherUrl` but `AppId == desktopId` also match.
  5. Launcher-only row (`IsLauncher:true`, `IsWindow:false`) never counts as running.
  6. Revision bumps on `rowsInserted`, `rowsRemoved`, `dataChanged`, `modelReset`; `taskState` under an appended row via new `setRows` reflects the change (query `revision` before/after).
  7. Swapping `model`/`desktopIds` properties bumps revision; old rows no longer match.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake -S tests/task-index -B build-tests/task-index && cmake --build build-tests/task-index && QT_QPA_PLATFORM=offscreen ./build-tests/task-index/task-index-test`
Expected: FAIL — taskindex.h does not exist (compile error).

- [ ] **Step 3: Implement `TaskIndex`** in `src/taskindex.{h,cpp}`

`QObject` following the style of `src/activitysource.h` (property accessors, NOTIFY `changed`). Internals: on model set, connect the four change signals to a `bumpRevision()`; maintain nothing eager — `taskState` walks the model on demand (rows are ≤ low hundreds; walking per click/bind-refresh is fine and avoids a cache to invalidate). Normalization helper: `desktopIdFromUrl(const QUrl &)` → basename, strip `.desktop`; accept `applications:` scheme and file/bare paths. `iconName` from `QIcon` role via `QIcon::name()`, empty → `"application-x-executable"`. Register in `src/plugin.cpp` and add to `src/CMakeLists.txt` `SOURCES` (header too, matching existing entries).

- [ ] **Step 4: Run tests to verify they pass** — same command as Step 2; Expected: PASS.
- [ ] **Step 5: Commit** `git add src/ tests/task-index && git commit -m "feat: TaskIndex model matching and per-app task state"`

---

### Task 2: `TaskIndex` — actions and unclaimed tasks

**Files:**
- Modify: `src/taskindex.h`, `src/taskindex.cpp`
- Test: `tests/task-index/tst_taskindex.cpp` (extend), `tests/task-index/mocktasksmodel.h` (use recorded invokable calls)

**Interfaces:**
- Produces:
  - `Q_INVOKABLE QVariantList unclaimedTasks() const` → list of `{desktopId, name, icon, active, minimized, count}` for every group-parent/window row whose normalized desktop ID is **not** in `desktopIds`, in model order.
  - `Q_INVOKABLE bool activate(const QString &desktopId)` — no matching rows → `false` (caller launches). Exactly one matched row → `requestActivate` it. Multiple → `requestActivate` the first non-minimized, else the first. Any matched row `isActive` → `requestToggleMinimized` on that row (click-on-focused minimizes).
  - `Q_INVOKABLE bool cycle(const QString &desktopId)` — matched rows with active window → `requestActivate` the row after the active one (wrap); no active window → behave as `activate`. No rows → `false`.
  - `Q_INVOKABLE void step(const QString &desktopId, int direction)` — `requestActivate` the row `direction` steps from the active one (wrap; if none active, first row). No-op when no rows.
  - `Q_INVOKABLE bool newInstance(const QString &desktopId)` — `requestNewInstance` first matched row; `false` when no rows.
- Consumes: Task 1's properties/matching; the mock's recording invokables.

- [ ] **Step 1: Write failing tests**: activate-when-idle returns false; activate on running non-focused app calls mock `requestActivate` with that row's index; activate on active app calls `requestToggleMinimized`; cycle advances to the row after the active one and wraps; step(+1/-1); newInstance calls `requestNewInstance` and returns false when idle; `unclaimedTasks` lists windows whose desktop ID is absent from `desktopIds`, excludes ones present, and returns `{}` when all claimed.
- [ ] **Step 2: Run tests to verify they fail** — same command; new invokables missing → compile error.
- [ ] **Step 3: Implement** the five invokables in `src/taskindex.cpp`. Model action calls via `QMetaObject::invokeMethod(model, "requestActivate", Q_ARG(QModelIndex, index))` — never include taskmanager headers.
- [ ] **Step 4: Run tests to verify they pass.**
- [ ] **Step 5: Commit** `git commit -m "feat: TaskIndex activate/cycle/step/new-instance and unclaimed tasks"`

---

### Task 3: `TaskArea.qml` — shared bridge component

**Files:**
- Create: `package/contents/ui/TaskArea.qml`
- Modify: `src/CMakeLists.txt` (register like `ApplicationMenu.qml` at `src/CMakeLists.txt:22-23`: `QT_RESOURCE_ALIAS "TaskArea.qml"`, `QT_QML_SKIP_CACHEGEN TRUE`, plus a `QML_FILES` entry)

**Interfaces:**
- Produces (group/standalone `main.qml` and `ApplicationMenu.qml` consume these; **the taskArea object is always a `var` in consumers — all of these must exist even in degraded mode via null checks**):
  - `property var desktopIds: []`
  - `readonly property var unclaimed: []` — array of `{type:"task", desktopId, name, icon, active, minimized, count}` ready to concat onto a Repeater model
  - `readonly property bool available: true`
  - `function stateFor(desktopId)` → `{running, active, minimized, count}` (defaults when no model)
  - `readonly property int revision` — mirrors the `TaskIndex` revision so QML bindings calling the functions above re-evaluate (bindings must reference `revision`)
  - `function activate(desktopId)` / `cycle(desktopId)` / `step(desktopId, direction)` / `newInstance(desktopId)` → `false` when not running (caller falls back to launch)
- Internals: `pragma ComponentBehavior: Bound`; `import org.kde.taskmanager 0.1 as TaskManager`; instantiates `TaskManager.TasksModel { groupMode: TaskManager.TasksModel.GroupApplications }` and `TaskIndex { id: index; model: tasksModel; desktopIds: root.desktopIds }`; `unclaimed` recomputed from `index.unclaimedTasks()` on `index.revision` change (bind the revision so it re-evaluates).

- [ ] **Step 1: Write `TaskArea.qml`** per the interface above. No `org.kde.taskmanager` import may appear in any other file (grep gate in Step 3).
- [ ] **Step 2: Build the plugin** `cmake -S . -B build/ci && cmake --build build/ci` — expected: configures and compiles (the file is a module QML type; no compile-time import resolution happens thanks to `QT_QML_SKIP_CACHEGEN`).
- [ ] **Step 3: Degradation inspection gate** — `grep -rn "taskmanager" package/contents/ui package-group/contents/ui` must show `org.kde.taskmanager` **only** in `TaskArea.qml`, and neither `main.qml` may reference the `TaskManager` namespace. Document in the file header comment: "Loaded only via Loader; import failure degrades to launcher-only mode."
- [ ] **Step 4: Commit** `git commit -m "feat: TaskArea shared bridge to Plasma TasksModel"`

Note: `TaskArea` itself cannot run in the offscreen CI env (no plasma-workspace) — it stays thin delegation; the Loader degradation pattern and the delegates it feeds are what CI can cover (Tasks 4–5) and the manual checklist covers the rest.

---

### Task 4: Group widget — live buttons, append zone, indicators, config key

**Files:**
- Modify: `package-group/contents/ui/main.qml` (buttons Repeater at `main.qml:175-278`, GridLayout count at `main.qml:140-160`)
- Modify: `package-group/contents/config/main.xml` (add entry after `items`, `main.xml:12-15`)
- Modify: `package-group/contents/ui/ConfigGeneral.qml` (checkbox)
- Create: `package-group/contents/ui/ClickMatrix.js` (pure `decideClick(desktopId, taskArea)` → `"launch"|"activate"|"minimize"` per the spec matrix)
- Test: `tests/stack-group-runtime/tst_tasks.qml` (new)

**Interfaces:**
- Consumes: `TaskArea` (Task 3); `GroupItems.decode` item shapes (`application` items: `desktopId`, optional `arguments`; `stack` items: `settings.applications` array of desktop IDs, `settings.customLaunchers` map with optional `desktopId` per launcher — `GroupItems.js:29-60`).
- Produces on `root` (group): `readonly property var taskArea` (null when disabled/degraded), `readonly property var panelItems` = `decoded.items` concat `taskArea ? taskArea.unclaimed : []`, and `desktopIds` collection covering: direct `application` items, every stack's `settings.applications`, and category stacks' matches via `ApplicationCategories.matching(catalog, cfg.applicationCategories)` (catalog is `root.catalog`); activity stacks' ids are added from the already-materialized `activityEntries` when present. **`customLaunchers` entries are never collected** — per spec, command items stay launch-only, and their windows auto-append instead. Pass `taskArea` into `GroupStackContent` as a new `property var taskArea: null` (file `package-group/contents/ui/GroupStackContent.qml`) — it forwards to `ApplicationMenu` in Task 5.

- [ ] **Step 1: Write failing QML tests** in `tests/stack-group-runtime/tst_tasks.qml` testing the button-behavior *logic* with `main.qml`'s patterns extracted to testable functions where needed; at minimum, with a mock `QtObject` taskArea (mirroring `tst_module.qml`'s mock-backend style): `stateFor` returns running/active maps, `activate` returns true/false per the matrix — assert the decision function `root.decideClick(desktopId, taskArea)` returns `"launch"|"activate"|"minimize"` per the spec matrix rows. (Main.qml's PlasmoidItem can't instantiate offscreen; put pure decision logic in a small `ClickMatrix.js` in `package-group/contents/ui/` so the test imports it directly.)
- [ ] **Step 2: Run the suite to verify it fails** — `QML_RUNNER -input tests/stack-group-runtime -o -,txt` with the env from Global Constraints.
- [ ] **Step 3: Implement**:
  - `main.xml`: `<entry name="taskTrackingEnabled" type="Bool"><default>true</default></entry>`; `ConfigGeneral.qml` checkbox i18n'd "Show running windows (task tracking)".
  - `main.qml`: `Loader { id: taskLoader; active: Plasmoid.configuration.taskTrackingEnabled; sourceComponent: Component { TaskArea {} } ; onStatusChanged: if (status === Loader.Error) root.taskAreaAvailable = false }` plus `root.taskArea = taskLoader.status === Loader.Ready ? taskLoader.item : null`. Feed `desktopIds` per Interfaces; `panelItems` drives the Repeater; `content.count` becomes `max(1, panelItems.length)`; GridLayout columns likewise.
  - Button delegate: for `application` items — `onClicked` routes through `taskArea.activate(modelData.desktopId)`, falling back to the existing `launcher.launch` when it returns false; a corner `MouseArea` (acceptedButtons `Qt.MiddleButton`) for `newInstance`-or-launch; `onWheel` → `step(modelData.desktopId, wheel.angleDelta.y > 0 ? 1 : -1)`; `highlighted` gains `|| taskState.active`; a running dot (small `Rectangle`, bottom-center, visible when `running`, colored active) and a count `PlasmaComponents.Label` badge (top-right, visible when `count > 1`). For `stack` items — running dot visible when any `desktopIds` of that stack's members is `running` (per-member query via `stateFor`). Task-type buttons (`type:"task"` from unclaimed) render through the same delegate with activate/cycle behavior and no launch fallback.
- [ ] **Step 4: Run suite + full gate** — `scripts/ci-run.sh`; expected ALL CHECKS PASSED.
- [ ] **Step 5: Commit** `git commit -m "feat: group widget live task buttons, append zone, and task config"`

---

### Task 5: Popup delegates — running dots and activate-on-click in menus

**Files:**
- Modify: `package/contents/ui/ApplicationMenu.qml` (delegate at `ApplicationMenu.qml:73-198`)
- Modify: `package-group/contents/ui/GroupStackContent.qml` (forward `taskArea`)
- Modify: `package/contents/ui/main.qml` (standalone: Loader + taskArea, pass to its `ApplicationMenu` at `main.qml:255+`, running-member dot on the stack button)
- Test: `tests/stack-group-runtime/tst_taskmenu.qml` (new; loads `TLB.ApplicationMenu` like `tst_module.qml`)

**Interfaces:**
- Consumes: `ApplicationMenu` gains `property var taskArea: null` (default null — every consumer without a taskArea keeps today's behavior exactly). Entry objects already carry `id` = desktop id for application entries (verify against `src/launcher.cpp` `applicationEntries`; if the id is not the desktop id there, match on a new `desktopId` field added by `applicationEntries` instead — pick one, keep tests consistent).
- Produces: delegate shows a running dot beside the icon (`visible: applicationScroll.taskArea && (applicationScroll.taskArea.revision, applicationScroll.taskArea.stateFor(modelData.id).running)` — the comma expression re-evaluates on `revision`, per Task 3's interface) and a count badge when `count > 1`; `onClicked` (`ApplicationMenu.qml:191-197`) first tries `taskArea.activate(modelData.id)` — on `true`, emit `activating()` + `activated()` (popup closes as today); on `false`, the existing `activateEntry` path runs. `GroupStackContent` forwards its new `taskArea` property into `ApplicationMenu`.
- Standalone `main.qml`: `Loader`-created `TaskArea` (same pattern as Task 4, always-on — spec gives standalone no config key), `desktopIds` = its `applications` list + category matches (it already computes matched ids); `customLaunchers` entries are never collected (command items stay launch-only, per spec); pass `taskArea` into the popup; a running-member dot on its single panel button when any member is running.

- [ ] **Step 1: Write failing tests** in `tst_taskmenu.qml` with a mock `QtObject` taskArea: clicking a running entry emits `activating()`/`activated()` and does **not** call the mock `launcher.activateEntry`; clicking a non-running entry does call it (existing behavior); with `taskArea: null`, all entries behave exactly as the pre-change `tst_module.qml` asserts (run that suite too).
- [ ] **Step 2: Run the suite to verify it fails** — same runner invocation.
- [ ] **Step 3: Implement** the property, dot/badge, and click routing in `ApplicationMenu.qml`; forward through `GroupStackContent.qml`; wire standalone `main.qml`.
- [ ] **Step 4: Run the whole gate** — `scripts/ci-run.sh`; expected ALL CHECKS PASSED.
- [ ] **Step 5: Commit** `git commit -m "feat: popup entries show running state and activate windows on click"`

---

### Task 6: CI wiring, docs, manual feel-test checklist

**Files:**
- Modify: `scripts/ci-run.sh` (add native suite at `scripts/ci-run.sh:42-46` pattern and `tests/task-index` QML-free native run; new QML suites `tst_tasks`/`tst_taskmenu` already live under `tests/stack-group-runtime`, covered by its existing line)
- Modify: `README.md` (task-tracking section: replaces the "not a task manager" disclaimer), `docs/FEATURE_TRACKER.md` (phase-1 shipped; future phases from the spec's list), `docs/TESTING_AND_STATUS.md` (new suites + manual checklist)
- Test: `scripts/ci-run.sh` full run.

- [ ] **Step 1: Wire `tests/task-index`** into `scripts/ci-run.sh` mirroring the `tests/native-menus` block (configure, build, run with `QT_QPA_PLATFORM=offscreen`).
- [ ] **Step 2: Run the full gate locally** — `scripts/ci-run.sh`; expected: ALL CHECKS PASSED (includes every new suite).
- [ ] **Step 3: Update docs** — README gains a short "Running windows" section describing click matrix, append zone, and the degraded mode; FEATURE_TRACKER marks phase 1 done with future-phase list; TESTING_AND_STATUS documents the two suites and the manual checklist: launch → activate → minimize → grouped cycling → scroll stepping → middle-click new instance → append on launch / disappear on close → popup running dots → standalone button dot → (degradation) uninstall plasma-workspace QML module presence can't be tested on the dev box, so verify by temporarily renaming the installed `org.kde/taskmanager` dir and confirming the widget still loads as a launcher, then restore.
- [ ] **Step 4: Commit** `git commit -m "feat: task tracking docs, CI wiring, and feel-test checklist"`

---

## Verification (whole plan)

- `scripts/ci-run.sh` green after every task that changes code or tests.
- Manual feel-test checklist (Task 6 Step 3) run once on the dev machine (Fedora + Wayland, environment of record) before declaring phase 1 done; results recorded in `docs/FEATURE_TRACKER.md`.

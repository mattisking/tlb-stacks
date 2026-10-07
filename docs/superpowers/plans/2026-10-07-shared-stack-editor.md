# Shared Stack Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One stack editor (Contents/Appearance) shared by the group widget (wrapped in a preview-strip + item-tree host) and the standalone widget (opened directly), replacing the two copy-pasted ConfigGeneral.qml editors without changing any saved data format.

**Architecture:** The single widget's `profileSettings()` object (`package/contents/ui/ConfigGeneral.qml:117-134`) and a group stack item's `settings` object (`package-group/contents/ui/GroupItems.js`) already use identical field names and the identical separator-ID member format (`tlbstacks-separator:<n>[:<label>]`). We extract that shared shape into a pure-data `StackSettingsEditor.qml` component (settings in, partial-changes signal out) plus small shared pieces (`CategoryChipBar.qml`, `AppPickerDialog.qml`, `StackMembers.js`). Each host persists changes through its own storage: the group host merges via `GroupItems.updateStack(items, id, changes)`; the single host maps change keys onto its flat `cfg_*` properties. New shared files follow the established module pattern: physically in `package/contents/ui/`, registered into `com.mattphilmon.tlbstacks` via `src/CMakeLists.txt`, so the group package gets them through its existing `import com.mattphilmon.tlbstacks`.

**Tech Stack:** QML (Qt Quick, Plasma Components, Kirigami), CMake/ECM, QtTest QML suites via `qmltestrunner`, Python unittest for profile tests (unaffected).

**Spec:** `docs/CONFIGURATION_DESIGN.md` (agreed direction and delivery order — this plan implements its step 2). Visual reference: mockup recording `Screencast_20261007_101026.webm` (frame analysis summarized in `docs/superpowers/plans/2026-10-07-shared-stack-editor-mockup-notes.md` if attached; otherwise rely on the descriptions inlined in the tasks below).

## Global Constraints

- **No schema changes.** Do not modify `package/contents/config/main.xml`, `package-group/contents/config/main.xml`, or `GroupItems.js`'s `decode`/`encode`/version logic. `GroupItems.js` may gain only additive pure functions (`replaceLauncher`).
- **All `cfg_*` property declarations stay on each config page.** Plasma binds them by name; removing one breaks Apply/OK. Single host must keep every declaration currently at `package/contents/ui/ConfigGeneral.qml:19-62`.
- **Apply/Cancel staging preserved.** Config pages only mutate `cfg_*` / `cfg_items`; Plasma owns commit.
- **Import/export behavior preserved verbatim** in both hosts: single `export`/`import` actions; group `exportGroup`/`export`/`importGroup` staging, error preservation, and folder-missing notices.
- **The groupSelection handoff stays isolated in the group host** (`package-group/contents/ui/ConfigGeneral.qml:87-98`, `src/groupselection.h`, `src/launcher.cpp:312-341`). The shared editor must not reference it. It may be reworked separately later.
- **Deferred — do not build in this plan:** inherited group defaults (`-1` values), group-level panel icon config key, launcher custom label/icon overrides (recording's "Use app icon" button), selectable tree child rows, drag-and-drop reordering. Tree children render as non-interactive summary labels.
- **Exact existing limits:** icon size 16–64 px; hover delay 0–2000 ms (step 50, editable); activity limit 1–50; applications per stack ≤ 2000; items per group ≤ 500.
- **Conventions:** Plasma Components + Kirigami idioms; `i18n()` for every user-visible string; `Accessible.name` on icon-only controls; dynamic-source results must look read-only (labels/counts, never editable member lists).
- **No commit touches both this plan's scope and the right-click/hover fix.** That work is uncommitted in the working tree; execute this plan in a worktree created from `HEAD` (superpowers:using-git-worktrees). Expected textual overlap at merge time: `package-group/contents/ui/ConfigGeneral.qml` and `src/CMakeLists.txt` — merge order: land the right-click fix first, then merge this branch.

## Review Focus

Failure modes the spec implies but no single screen shows; each is pinned to a test below.

1. **Switching a populated stack's source back and forth must not lose settings** (folder → applications → folder keeps `folderUrl`/`folderFilters`). Pinned in Task 6 (Step 1 test).
2. **Duplicate applications must stay impossible on every add path** (AppPicker excludes members; `GroupItems.add` blocks group-level dups; member `addMember` rejects ids already present). Pinned in Tasks 4 and 6.
3. **Separator IDs with colons in labels must round-trip** (`renameSeparator` must not split on every colon). Pinned in Task 1.
4. **Unavailable applications must still render** (name fallback "%1 (unavailable)", no crash on unknown desktopId) in member lists, tree summaries, and picker. Pinned in Task 6.
5. **`decoded.error` (forward-version group config) must keep the whole editor disabled and preserved** — the rewrite must not make a malformed `cfg_items` interactive. Pinned in Task 8 (Step 1 test, port of existing behavior).

---

### Task 1: Shared `StackMembers.js` separator helpers

**Files:**
- Create: `package/contents/ui/StackMembers.js`
- Modify: `src/CMakeLists.txt` (register the JS into the module, mirroring `ApplicationCategories.js`)
- Modify: `package/contents/ui/ConfigGeneral.qml:205-231` (replace local separator functions with module usage)
- Create test: `tests/stack-editor/tst_members.qml`

**Interfaces:**
- Produces (module JS namespace, usable as `StackMembers.xxx` in any QML importing `com.mattphilmon.tlbstacks`):
  `isSeparator(id)`, `separatorNumber(id)`, `separatorLabel(id)`, `appendSeparator(applications)`, `renameSeparator(applications, id, label)` — same semantics as the current single-host locals and `GroupItems.js:86-102`.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing test** — create `tests/stack-editor/tst_members.qml`:

```qml
import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

TestCase {
    name: "StackMembers"
    function test_separator_detection() {
        verify(StackMembers.isSeparator("tlbstacks-separator:1"))
        verify(StackMembers.isSeparator("tlbstacks-separator:2:Games"))
        verify(StackMembers.isSeparator("tlbstacks-separator:3:with:colons"))
        verify(!StackMembers.isSeparator("org.kde.dolphin"))
        verify(!StackMembers.isSeparator(""))
        verify(!StackMembers.isSeparator(null))
    }
    function test_label_roundtrip_keeps_colons() {
        const id = "tlbstacks-separator:7:STALKER:Shadow"
        compare(StackMembers.separatorNumber(id), "7")
        compare(StackMembers.separatorLabel(id), "STALKER:Shadow")
        const renamed = StackMembers.renameSeparator(["a.desktop", id, "b.desktop"], id, " New : Label ")
        compare(renamed[1], "tlbstacks-separator:7:New : Label")
        compare(StackMembers.renameSeparator(renamed, renamed[1], "  "), "tlbstacks-separator:7")
        // Non-separator ids pass through untouched.
        compare(StackMembers.renameSeparator(["a.desktop"], "a.desktop", "x"), "a.desktop")
    }
    function test_append_separator_finds_free_number() {
        const apps = ["tlbstacks-separator:1", "tlbstacks-separator:2:X", "app.desktop"]
        const next = StackMembers.appendSeparator(apps)
        compare(next.length, apps.length + 1)
        verify(next.includes("tlbstacks-separator:3"))
        // 2000-member cap holds.
        const full = new Array(2000).fill("app.desktop")
        compare(StackMembers.appendSeparator(full).length, 2000)
    }
}
```

- [ ] **Step 2: Run it to verify it fails** — build the module, then run the new suite:

```bash
cmake -S . -B build/ci && cmake --build build/ci -j"$(nproc)"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
```

Expected: FAIL — `StackMembers` is not defined (module has no such JS).

- [ ] **Step 3: Implement** — create `package/contents/ui/StackMembers.js`:

```js
.pragma library

// Shared member-ID helpers for stacks. Both widget packages and the group
// schema use "tlbstacks-separator:<number>[:<label>]" entries inside the
// applications list. GroupItems.js keeps its own copies for its schema flow.
function isSeparator(id) {
    return typeof id === "string" && id.startsWith("tlbstacks-separator:")
}
function separatorNumber(id) {
    const rest = id.slice("tlbstacks-separator:".length)
    const colon = rest.indexOf(":")
    return colon < 0 ? rest : rest.slice(0, colon)
}
function separatorLabel(id) {
    const rest = id.slice("tlbstacks-separator:".length)
    const colon = rest.indexOf(":")
    return colon < 0 ? "" : rest.slice(colon + 1)
}
function appendSeparator(applications) {
    if (applications.length >= 2000) return applications
    const used = applications.filter(isSeparator).map(separatorNumber)
    let number = 1
    while (used.includes(String(number))) number++
    return applications.concat(["tlbstacks-separator:" + number])
}
function renameSeparator(applications, id, label) {
    if (!isSeparator(id)) return applications
    const base = "tlbstacks-separator:" + separatorNumber(id)
    const clean = label.trim().slice(0, 64)
    const updated = base + (clean ? ":" + clean : "")
    return applications.map(value => value === id ? updated : value)
}
```

Register it in `src/CMakeLists.txt` exactly like `ApplicationCategories.js` (a `set_source_files_properties("../package/contents/ui/StackMembers.js" PROPERTIES QT_RESOURCE_ALIAS "StackMembers.js" QT_QML_SKIP_CACHEGEN TRUE)` block plus the path in `QML_FILES`).

- [ ] **Step 4: Refactor the single host** — in `package/contents/ui/ConfigGeneral.qml`, delete the local `separatorPrefix` property and the `isSeparator`/`separatorNumber`/`separatorLabel`/`setSeparatorLabel` bodies that duplicate the above (lines 63, 205-231). Replace their call sites: `root.isSeparator(id)` → `StackMembers.isSeparator(id)`, `root.separatorLabel(id)` → `StackMembers.separatorLabel(id)`, and rewrite `setSeparatorLabel(index, label)` as:

```qml
function setSeparatorLabel(index, label) {
    const next = Array.from(root.cfg_applications || [])
    if (index < 0 || index >= next.length || !StackMembers.isSeparator(next[index])) return
    const updated = StackMembers.renameSeparator([next[index]], next[index], label)[0]
    if (updated === next[index]) return
    next[index] = updated
    root.cfg_applications = next
}
```

(`insertSeparator` at lines 277-288 switches its `used`-number logic to `StackMembers.appendSeparator` semantics — keep the insert-at-currentIndex behavior, only swap the number-generation.) The module import at line 10 (`import com.mattphilmon.tlbstacks`) already exposes the `StackMembers` namespace.

- [ ] **Step 5: Run the new suite plus the existing group suite** (regression — group host untouched but module build changed):

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/navigation -o -,txt
```

Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/StackMembers.js src/CMakeLists.txt package/contents/ui/ConfigGeneral.qml tests/stack-editor/tst_members.qml
git commit -m "Share separator member-ID helpers through the QML module"
```

### Task 2: `GroupItems.replaceLauncher` — swap a launcher's application

**Files:**
- Modify: `package-group/contents/ui/GroupItems.js` (append one pure function)
- Modify test: `tests/navigation/tst_groupitems.qml`

**Interfaces:**
- Produces: `GroupItems.replaceLauncher(items, id, desktopId)` → new items array with the launcher's `desktopId` replaced (same item `id`, same position). Returns input unchanged if `id` not found, `desktopId` falsy, or another item already uses `desktopId`.

- [ ] **Step 1: Write the failing test** — append to `tests/navigation/tst_groupitems.qml`:

```qml
function test_replace_launcher_keeps_id_and_position_and_blocks_duplicates() {
    let items = GroupItems.add([], "one.desktop")
    items = GroupItems.add(items, "two.desktop")
    const replaced = GroupItems.replaceLauncher(items, "item-1", "three.desktop")
    compare(replaced.length, 2)
    compare(replaced[0].id, "item-1")
    compare(replaced[0].desktopId, "three.desktop")
    // Same app stays valid and unchanged.
    compare(GroupItems.replaceLauncher(replaced, "item-1", "three.desktop"), replaced)
    // Duplicate rejection: item-2 already owns two.desktop.
    compare(GroupItems.replaceLauncher(replaced, "item-1", "two.desktop"), replaced)
    // Unknown ids pass through.
    compare(GroupItems.replaceLauncher(replaced, "missing", "x.desktop"), replaced)
    verify(!GroupItems.decode(GroupItems.encode(replaced)).error)
}
```

(Adjust the `import ... as GroupItems` alias to match the file's existing import.)

- [ ] **Step 2: Run it to verify it fails**

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/navigation -o -,txt
```

Expected: FAIL — `replaceLauncher` is not a function.

- [ ] **Step 3: Implement** — append to `package-group/contents/ui/GroupItems.js`:

```js
function replaceLauncher(items, id, desktopId) {
    if (!desktopId || !items.some(item => item.id === id && item.type === "application")) return items
    if (items.some(item => item.type === "application" && item.desktopId === desktopId && item.id !== id)) return items
    return items.map(item => item.id === id ? Object.assign({}, item, {desktopId: desktopId}) : item)
}
```

- [ ] **Step 4: Run the suite** — same command as Step 2. Expected: PASS (existing tests included).

- [ ] **Step 5: Commit**

```bash
git add package-group/contents/ui/GroupItems.js tests/navigation/tst_groupitems.qml
git commit -m "Add GroupItems.replaceLauncher for launcher application swaps"
```

### Task 3: `CategoryChipBar.qml` — filterable chip cloud

Per the recording (frames 07–08): rounded pill chips in a wrapping flow under a "Filter categories…" field, selected = filled, plus a live matches count caption. Chips are the selection control (replacing the checklist); the count/preview is clearly read-only.

**Files:**
- Create: `package/contents/ui/CategoryChipBar.qml`
- Modify: `src/CMakeLists.txt` (register like `ApplicationIcon.qml`)
- Create test: `tests/stack-editor/tst_chipbar.qml`

**Interfaces:**
- Produces: QML component — `property var categories: []` (available names), `property var selected: []`, `property string caption: ""` (read-only line under the chips), signal `categoryToggled(string name, bool on)`.

- [ ] **Step 1: Write the failing test** — create `tests/stack-editor/tst_chipbar.qml`:

```qml
import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 480; height: 400
    CategoryChipBar {
        id: bar
        anchors.fill: parent
        categories: ["ActionGame", "ArcadeGame", "BoardGame", "Audio", "Calculator"]
        selected: ["ActionGame", "BoardGame"]
        caption: "Matches 14 applications"
    }
    SignalSpy { id: spy; target: bar; signalName: "categoryToggled" }
    TestCase {
        name: "CategoryChipBar"
        when: windowShown
        function test_chips_toggle_and_filter() {
            compare(spy.count, 0)
            const arcade = findChild(bar, "chip-ArcadeGame")
            verify(arcade)
            arcade.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "ArcadeGame")
            verify(spy.signalArguments[0][1])   // was off → toggling selects
            const selected = findChild(bar, "chip-ActionGame")
            selected.clicked()
            compare(spy.signalArguments[1][1], false)  // was on → toggling deselects
        }
        function test_filter_hides_nonmatching_chips() {
            const search = findChild(bar, "chipFilter")
            search.text = "game"
            verify(!findChild(bar, "chip-Audio").visible)
            verify(findChild(bar, "chip-ActionGame").visible)
        }
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cmake --build build/ci -j"$(nproc)"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
```

Expected: FAIL — `CategoryChipBar` is not a type.

- [ ] **Step 3: Implement** — create `package/contents/ui/CategoryChipBar.qml`:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Filterable cloud of category chips (mockup frames 07-08): pills in a
// wrapping flow, filled = selected. Selection is data-driven via
// categoryToggled(name, on); the host owns the `selected` array.
ColumnLayout {
    id: root

    property var categories: []
    property var selected: []
    property string caption: ""
    signal categoryToggled(string name, bool on)

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.TextField {
        id: filter
        objectName: "chipFilter"
        Layout.fillWidth: true
        placeholderText: i18n("Filter categories…")
        clearButtonShown: true
        Keys.onReturnPressed: event => { event.accepted = true }
        Keys.onEnterPressed: event => { event.accepted = true }
    }

    Flow {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: {
                const query = filter.text.toLowerCase()
                return root.categories.filter(name => name.toLowerCase().includes(query))
            }
            delegate: PlasmaComponents.ToolButton {
                id: chip
                required property string modelData
                objectName: "chip-" + modelData
                text: modelData
                checkable: true
                checked: root.selected.includes(modelData)
                Accessible.name: i18n("Category %1", modelData)
                onClicked: root.categoryToggled(modelData, !checked)
                // `checked` follows the host's `selected` array; flip visually on click.
                Connections {
                    target: root
                    function onSelectedChanged() { chip.checked = root.selected.includes(chip.modelData) }
                }
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.caption.length > 0
        text: root.caption
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }
}
```

Register in `src/CMakeLists.txt` like `ApplicationIcon.qml` (`set_source_files_properties` + `QML_FILES`).

- [ ] **Step 4: Run the suite** — same command as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/CategoryChipBar.qml src/CMakeLists.txt tests/stack-editor/tst_chipbar.qml
git commit -m "Add shared CategoryChipBar chip cloud component"
```

### Task 4: `AppPickerDialog.qml` — search-on-add application picker

Per the review: "search takes space only when you're adding an application." Modal dialog listing catalog apps, excluding existing members.

**Files:**
- Create: `package/contents/ui/AppPickerDialog.qml`
- Modify: `src/CMakeLists.txt` (register)
- Create test: `tests/stack-editor/tst_apppicker.qml`

**Interfaces:**
- Produces: QQC2.Dialog — `property var applications: []` (catalog `[{desktopId, name, icon}]`), `property var exclude: []` (desktopIds already members; hidden), signal `picked(string desktopId)`; `function openPicker()` resets search + focus and opens.
- Consumes: host catalog shape `{desktopId, name, icon}` (same as `launcher.applications()`).

- [ ] **Step 1: Write the failing test** — create `tests/stack-editor/tst_apppicker.qml`:

```qml
import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 500; height: 400
    AppPickerDialog {
        id: picker
        anchors.centerIn: parent
        applications: [
            {desktopId: "org.kde.dolphin", name: "Dolphin", icon: "system-file-manager"},
            {desktopId: "firefox", name: "Firefox", icon: "firefox"},
            {desktopId: "code", name: "Visual Studio Code", icon: "code"}
        ]
        exclude: ["firefox"]
    }
    SignalSpy { id: spy; target: picker; signalName: "picked" }
    TestCase {
        name: "AppPickerDialog"
        when: windowShown
        function test_excluded_apps_are_hidden_and_pick_emits() {
            picker.openPicker()
            verify(picker.opened)
            verify(!findChild(picker, "pick-firefox"))
            const row = findChild(picker, "pick-org.kde.dolphin")
            verify(row)
            row.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "org.kde.dolphin")
            verify(!picker.opened)
        }
        function test_search_narrows_the_list() {
            picker.openPicker()
            const search = findChild(picker, "pickerSearch")
            search.text = "code"
            verify(!findChild(picker, "pick-org.kde.dolphin").visible)
            verify(findChild(picker, "pick-code").visible)
            picker.close()
        }
    }
}
```

- [ ] **Step 2: Run it to verify it fails** — build + run `tests/stack-editor`. Expected: FAIL — `AppPickerDialog` is not a type.

- [ ] **Step 3: Implement** — create `package/contents/ui/AppPickerDialog.qml`:

```qml
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Searchable application picker shown only while adding (review note:
// search takes space only when adding). Emits picked(desktopId).
QQC2.Dialog {
    id: root

    property var applications: []
    property var exclude: []
    signal picked(string desktopId)

    modal: true
    title: i18n("Add application")
    standardButtons: QQC2.Dialog.Cancel
    anchors.centerIn: parent
    width: Math.min(Kirigami.Units.gridUnit * 28, (parent ? parent.width : 600) - Kirigami.Units.gridUnit * 2)
    height: Math.min(Kirigami.Units.gridUnit * 28, (parent ? parent.height : 500) - Kirigami.Units.gridUnit * 2)

    function openPicker() {
        search.text = ""
        open()
        search.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.TextField {
            id: search
            objectName: "pickerSearch"
            Layout.fillWidth: true
            placeholderText: i18n("Search applications…")
            clearButtonShown: true
            Keys.onReturnPressed: event => { event.accepted = true }
            Keys.onEnterPressed: event => { event.accepted = true }
        }
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            ListView {
                id: list
                clip: true
                model: {
                    const query = search.text.toLowerCase()
                    return root.applications.filter(app =>
                        !root.exclude.includes(app.desktopId) &&
                        app.name.toLowerCase().includes(query))
                }
                delegate: PlasmaComponents.ItemDelegate {
                    id: row
                    required property var modelData
                    objectName: "pick-" + modelData.desktopId
                    width: ListView.view.width
                    text: modelData.name
                    icon.name: modelData.icon || "application-x-executable"
                    onClicked: { root.picked(modelData.desktopId); root.close() }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: list.count === 0
                    text: search.text.length > 0 ? i18n("No applications match your search.")
                        : i18n("Every application is already in this stack.")
                }
            }
        }
    }
}
```

Register in `src/CMakeLists.txt`.

- [ ] **Step 4: Run the suite** — Expected: PASS (chip/member tests still green).

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/AppPickerDialog.qml src/CMakeLists.txt tests/stack-editor/tst_apppicker.qml
git commit -m "Add shared AppPickerDialog for search-on-add"
```

### Task 5: `StackSettingsEditor.qml` — shell, kind segments, Appearance page

The core shared component. Per the recording: 4-segment kind selector (icon over label, highlighted), Contents/Appearance tabs, Appearance = Name, icon row (Choose… / Image… / Reset — **our** icon chooser + image import, not raw icon-name fields), Icons only, Icon size, Hover delay.

**Files:**
- Create: `package/contents/ui/StackSettingsEditor.qml`
- Modify: `src/CMakeLists.txt` (register)
- Create test: `tests/stack-editor/tst_stacksettings.qml`

**Interfaces:**
- Produces: QML component —
  - `property var settings: ({})` — one stack's settings object (field names identical to the group schema: `menuSource, groupName, groupIcon, applications, applicationIcons, iconsOnly, menuIconSize, hoverDelay, applicationCategories, activityOrder, activityLimit, activityCurrent, folderUrl, folderFilters`)
  - `property var catalog: []` — `[{desktopId, name, icon}]`
  - `property var launcher: null` — host's `Launcher` instance (name/icon lookups, `manageIcon`)
  - `property string stackIconDefault: "applications-all"`
  - `signal settingsEdited(var changes)` — partial `{field: value}` object; the host persists
  - Testable functions: `setKind(kind)`, `setField(key, value)`, `applyIconResult(target, icon)` (target `""` = stack icon, else desktopId)
- Consumes: `StackMembers`, `IconOverrides`, `ApplicationIcon` (module siblings, relative imports like `ApplicationMenu.qml` uses).

- [ ] **Step 1: Write the failing tests** — create `tests/stack-editor/tst_stacksettings.qml`:

```qml
import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 760; height: 560
    StackSettingsEditor {
        id: editor
        anchors.fill: parent
        settings: ({
            menuSource: "applications", groupName: "Dev", groupIcon: "applications-development",
            applications: ["code.desktop", "tlbstacks-separator:1"],
            applicationIcons: {}, iconsOnly: false, menuIconSize: 22, hoverDelay: 250,
            applicationCategories: [], activityOrder: "recent", activityLimit: 10,
            activityCurrent: false, folderUrl: "", folderFilters: "*" })
        catalog: [
            {desktopId: "code.desktop", name: "Visual Studio Code", icon: "code"},
            {desktopId: "dolphin.desktop", name: "Dolphin", icon: "system-file-manager"},
            {desktopId: "gone.desktop", name: "Gone", icon: "gone"}
        ]
    }
    SignalSpy { id: spy; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorShell"
        when: windowShown
        function init() { spy.clear() }

        function test_kind_segments_emit_menuSource() {
            const folder = findChild(editor, "kind-folder")
            folder.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], {menuSource: "folder"})
        }
        function test_appearance_fields_emit_partial_changes() {
            editor.setField("groupName", "Development")
            compare(spy.signalArguments[0][0], {groupName: "Development"})
            editor.setField("iconsOnly", true)
            compare(spy.signalArguments[1][0], {iconsOnly: true})
            editor.setField("menuIconSize", 32)
            compare(spy.signalArguments[2][0], {menuIconSize: 32})
            editor.setField("hoverDelay", 400)
            compare(spy.signalArguments[3][0], {hoverDelay: 400})
        }
        function test_icon_result_applies_to_stack_or_member() {
            editor.applyIconResult("", "custom-icon")
            compare(spy.signalArguments[0][0].groupIcon, "custom-icon")
            editor.applyIconResult("code.desktop", "/images/code.png")
            compare(spy.signalArguments[1][0].applicationIcons["code.desktop"], "/images/code.png")
            editor.applyIconResult("code.desktop", "")
            compare(spy.signalArguments[2][0].applicationIcons["code.desktop"], undefined)
        }
        function test_icon_reset_uses_default() {
            editor.applyIconResult("", "")
            compare(spy.signalArguments[0][0].groupIcon, "applications-all")
        }
    }
}
```

- [ ] **Step 2: Run it to verify it fails** — build + run `tests/stack-editor`. Expected: FAIL — `StackSettingsEditor` is not a type.

- [ ] **Step 3: Implement the shell + Appearance page** — create `package/contents/ui/StackSettingsEditor.qml`:

```qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
import org.kde.plasma.components as PlasmaComponents
import "IconOverrides.js" as IconOverrides

// One stack's settings editor, shared by the group host (tree + preview)
// and the standalone host (opened directly). Pure data in, partial changes
// out: the host persists `changes` through its own storage. Never touches
// cfg_* properties or the groupSelection handoff.
ColumnLayout {
    id: root

    property var settings: ({})
    property var catalog: []
    property var launcher: null
    property string stackIconDefault: "applications-all"
    signal settingsEdited(var changes)

    readonly property var kinds: [
        { id: "applications", label: i18n("Selected"),  icon: "view-list-icons" },
        { id: "folder",       label: i18n("Live folder"), icon: "folder" },
        { id: "categories",   label: i18n("Categories"),  icon: "tag" },
        { id: "activity",     label: i18n("Recent"),      icon: "document-open-recent" }
    ]
    readonly property string menuSource: settings.menuSource || "applications"
    // Group-decoded stacks carry applicationIcons as an object; the single
    // host's cfg_applicationIcons is a JSON string. Accept both.
    readonly property var applicationIcons: (typeof settings.applicationIcons === "object"
        && settings.applicationIcons !== null && !Array.isArray(settings.applicationIcons))
        ? settings.applicationIcons : IconOverrides.parse(settings.applicationIcons || "{}")

    function setKind(kind) { settingsEdited({menuSource: kind}) }
    function setField(key, value) { const c = {}; c[key] = value; settingsEdited(c) }

    // ---- icon flow (Choose… / Image… / Reset, per existing single-host behavior)
    property string iconTarget: ""   // "" = the stack icon; otherwise a desktopId
    property var iconPending: null

    function chooseIcon(target, fromFile) {
        iconTarget = target
        if (fromFile) iconFileDialog.open()
        else {
            stackIconDialog.title = target ? i18n("Choose an application icon") : i18n("Choose a stack icon")
            stackIconDialog.open()
        }
    }
    function setCustomIcon(target, icon) {
        if (!launcher || launcher.profileBusy) return
        iconPending = {id: launcher.profileOperation("manageIcon", {icon: icon}), target: target}
    }
    function applyIconResult(target, icon) {
        if (!target) { settingsEdited({groupIcon: icon || stackIconDefault}); return }
        const icons = Object.assign({}, applicationIcons)
        if (icon) icons[target] = icon; else delete icons[target]
        settingsEdited({applicationIcons: icons})
    }
    Connections {
        target: root.launcher
        function onProfileFinished(requestId, result) {
            if (!root.iconPending || root.iconPending.id !== requestId) return
            const target = root.iconPending.target
            root.iconPending = null
            if (result.ok) root.applyIconResult(target, result.icon)
        }
    }
    IconThemes.IconDialog { id: stackIconDialog; onIconNameChanged: if (iconName.length > 0) root.applyIconResult(root.iconTarget, iconName) }
    Dialogs.FileDialog {
        id: iconFileDialog
        title: i18n("Choose an icon image")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("Icon images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.ico)")]
        onAccepted: {
            const url = selectedFile.toString()
            if (url.startsWith("file://"))
                root.setCustomIcon(root.iconTarget, decodeURIComponent(url.substring(7)))
        }
    }

    // ---- kind segments (mockup: icon over label, highlighted active)
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: root.kinds
            delegate: PlasmaComponents.ToolButton {
                id: segment
                required property var modelData
                objectName: "kind-" + modelData.id
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                display: QQC2.AbstractButton.TextUnderIcon
                text: modelData.label
                icon.name: modelData.icon
                checked: root.menuSource === modelData.id
                Accessible.name: i18n("Stack type %1", modelData.label)
                onClicked: root.setKind(modelData.id)
            }
        }
    }

    QQC2.TabBar {
        id: tabs
        Layout.fillWidth: true
        QQC2.TabButton { text: i18n("Contents") }
        QQC2.TabButton { text: i18n("Appearance") }
    }

    QQC2.StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabs.currentIndex

        // Contents (Task 6 fills this placeholder container — the four source
        // pages live in `contentsPages` below once implemented).
        Item { id: contentsPages; Layout.fillWidth: true; Layout.fillHeight: true }

        // ---- Appearance (Flickable so it scrolls independently of the tree)
        QQC2.Flickable {
            contentWidth: width
            contentHeight: appearanceForm.implicitHeight
            clip: true
            Kirigami.FormLayout {
                id: appearanceForm
                width: parent.width
                PlasmaComponents.TextField {
                    Kirigami.FormData.label: i18n("Name:")
                    text: root.settings.groupName || ""
                    placeholderText: i18n("Stack name")
                    maximumLength: 256
                    onTextEdited: root.setField("groupName", text)
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Icon:")
                    Kirigami.Icon {
                        source: IconOverrides.get(root.applicationIcons, "") || root.settings.groupIcon || root.stackIconDefault
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                    }
                    PlasmaComponents.Button { text: i18n("Choose…"); onClicked: root.chooseIcon("", false) }
                    PlasmaComponents.Button { text: i18n("Image…"); onClicked: root.chooseIcon("", true) }
                    PlasmaComponents.Button {
                        text: i18n("Reset")
                        enabled: root.settings.groupIcon !== root.stackIconDefault
                        onClicked: root.applyIconResult("", "")
                    }
                }
                PlasmaComponents.CheckBox {
                    Kirigami.FormData.label: i18n("Display:")
                    text: root.menuSource === "folder" ? i18n("Icons only (unavailable for Live Folder)")
                        : i18n("Icons only (show names on hover)")
                    enabled: root.menuSource !== "folder"
                    checked: root.settings.iconsOnly || false
                    onToggled: root.setField("iconsOnly", checked)
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Icon size (px):")
                    from: 16; to: 64
                    editable: true
                    value: root.settings.menuIconSize || 22
                    onValueModified: root.setField("menuIconSize", value)
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Hover delay (ms):")
                    from: 0; to: 2000; stepSize: 50
                    editable: true
                    value: root.settings.hoverDelay || 250
                    onValueModified: root.setField("hoverDelay", value)
                }
            }
        }
    }
}
```

Register in `src/CMakeLists.txt`. Note: the `IconOverrides.get(icons, "")` pattern mirrors the single host's menu-icon precedence (`custom || groupIcon`); verify `IconOverrides.get` with an empty key returns `""` (read `package/contents/ui/IconOverrides.js` first and adapt: if the map never uses an empty key, use `root.settings.groupIcon || root.stackIconDefault` directly).

- [ ] **Step 4: Run the suite** — Expected: PASS for `StackSettingsEditorShell` (Content page tests come in Task 6).

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/StackSettingsEditor.qml src/CMakeLists.txt tests/stack-editor/tst_stacksettings.qml
git commit -m "Add shared StackSettingsEditor shell with Appearance page"
```

### Task 6: `StackSettingsEditor` — Contents pages

Four source pages. Selected: member list with separators, per-member icon menu, add via `AppPickerDialog`. Categories: `CategoryChipBar` + read-only matches caption/preview. Activity: order/limit/scope + optional chips. Folder: picker + patterns.

**Files:**
- Modify: `package/contents/ui/StackSettingsEditor.qml` (replace the `contentsPages` placeholder Item)
- Modify test: `tests/stack-editor/tst_stacksettings.qml`

**Interfaces:**
- Produces (additional testable functions): `addMember(desktopId)`, `removeMember(index)`, `moveMember(index, delta)`, `addSeparator()`, `renameSeparator(id, label)`, `memberName(desktopId)`, `toggleCategory(name, on)`, `matchesCount()` (int, via `ApplicationCategories.matching(catalog, settings.applicationCategories).length`).
- Consumes: Task 3 `CategoryChipBar`, Task 4 `AppPickerDialog`, Task 1 `StackMembers`, module `ApplicationCategories.js`.

- [ ] **Step 1: Write the failing tests** — append to `tests/stack-editor/tst_stacksettings.qml` (same file, new TestCase):

```qml
    SignalSpy { id: spy2; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorContents"
        when: windowShown
        function init() { spy2.clear() }

        function test_member_add_rejects_duplicates() {
            editor.addMember("code.desktop")
            compare(spy2.count, 0)   // already a member
            editor.addMember("dolphin.desktop")
            const apps = spy2.signalArguments[0][0].applications
            compare(apps, ["code.desktop", "tlbstacks-separator:1", "dolphin.desktop"])
        }
        function test_member_move_remove_and_separator_rename() {
            editor.moveMember(2, -1)   // dolphin above separator
            compare(spy2.signalArguments[0][0].applications,
                ["code.desktop", "dolphin.desktop", "tlbstacks-separator:1"])
            editor.moveMember(0, -5)   // out of range: no-op
            editor.removeMember(0)
            compare(spy2.signalArguments[2][0].applications, ["dolphin.desktop", "tlbstacks-separator:1"])
            editor.renameSeparator("tlbstacks-separator:1", "IDEs : Tools")
            compare(spy2.signalArguments[3][0].applications, ["dolphin.desktop", "tlbstacks-separator:1:IDEs : Tools"])
        }
        function test_add_separator_finds_free_number() {
            editor.addSeparator()
            compare(spy2.signalArguments[0][0].applications[2], "tlbstacks-separator:2")
        }
        function test_unavailable_member_names_fall_back() {
            compare(editor.memberName("gone.desktop"), "Gone")
            const fallback = String(editor.memberName("not-installed.desktop"))
            verify(fallback.indexOf("not-installed.desktop") >= 0)   // id stays visible
            verify(fallback.length > "not-installed.desktop".length) // wrapped in fallback text
        }
        function test_category_toggle_emits_next_array() {
            editor.setKind("categories")
            editor.toggleCategory("Development", true)
            compare(spy2.signalArguments[1][0].applicationCategories, ["Development"])
            editor.toggleCategory("Network", true)
            compare(spy2.signalArguments[2][0].applicationCategories, ["Development", "Network"])
            editor.toggleCategory("Development", false)
            compare(spy2.signalArguments[3][0].applicationCategories, ["Network"])
        }
        function test_folder_and_activity_fields() {
            editor.setField("folderUrl", "file:///home/matt/Documents")
            compare(spy2.signalArguments[0][0].folderUrl, "file:///home/matt/Documents")
            editor.setField("folderFilters", "*.pdf;*.docx")
            compare(spy2.signalArguments[1][0].folderFilters, "*.pdf;*.docx")
            editor.setField("activityOrder", "frequent")
            compare(spy2.signalArguments[2][0].activityOrder, "frequent")
            editor.setField("activityLimit", 20)
            compare(spy2.signalArguments[3][0].activityLimit, 20)
            editor.setField("activityCurrent", true)
            compare(spy2.signalArguments[4][0].activityCurrent, true)
        }
    }
```

- [ ] **Step 2: Run to verify failures** — build + run `tests/stack-editor`. Expected: FAIL — member/category functions not defined.

- [ ] **Step 3: Implement the functions + four Contents pages.** Add to the `StackSettingsEditor.qml` function block:

```qml
    function memberName(desktopId) {
        const app = catalog.find(entry => entry.desktopId === desktopId)
        return app ? app.name : i18n("%1 (unavailable)", desktopId)
    }
    function memberIcon(desktopId) {
        return IconOverrides.get(applicationIcons, desktopId) ||
            (catalog.find(entry => entry.desktopId === desktopId) || {}).icon ||
            "application-x-executable"
    }
    function emitApplications(next) { settingsEdited({applications: next}) }
    function addMember(desktopId) {
        if (!desktopId || (settings.applications || []).includes(desktopId)
            || (settings.applications || []).length >= 2000) return
        emitApplications((settings.applications || []).concat([desktopId]))
    }
    function removeMember(index) {
        const next = (settings.applications || []).slice()
        if (index < 0 || index >= next.length) return
        next.splice(index, 1)
        emitApplications(next)
    }
    function moveMember(index, delta) {
        const apps = settings.applications || []
        const target = index + delta
        if (index < 0 || index >= apps.length || target < 0 || target >= apps.length) return
        const next = apps.slice()
        next.splice(target, 0, next.splice(index, 1)[0])
        emitApplications(next)
    }
    function addSeparator() { emitApplications(StackMembers.appendSeparator(settings.applications || [])) }
    function renameSeparator(id, label) { emitApplications(StackMembers.renameSeparator(settings.applications || [], id, label)) }
    function toggleCategory(name, on) {
        const next = (settings.applicationCategories || []).filter(value => value !== name)
        if (on) next.push(name)
        settingsEdited({applicationCategories: next})
    }
    function matchesCount() {
        return ApplicationCategories.matching(catalog, settings.applicationCategories || []).length
    }
```

(`ApplicationCategories` is a module sibling — import it at the top of `StackSettingsEditor.qml` exactly as `package/contents/ui/ConfigGeneral.qml:5` does today: `import "ApplicationCategories.js" as ApplicationCategories`.)

Replace the `contentsPages` placeholder `Item` with a `QQC2.StackLayout` whose `currentIndex` binds to the kind row (`kinds.findIndex(k => k.id === menuSource)`), holding four pages:

**Selected-applications page** — `ColumnLayout` with a `ScrollView` + `ListView` (`model: settings.applications`, `objectName: "memberList"`). Delegate `RowLayout` (required `modelData` string, `index` int): `ApplicationIcon` (source `memberIcon`, fallback like the single host's rows) + `PlasmaComponents.Label` (`memberName`, elide) for non-separators; a centered `QQC2.TextField` (`placeholderText: i18n("Separator label (optional)")`, `maximumLength: 64`, `onEditingFinished: root.renameSeparator(modelData, text)`) between two thin separator `Rectangle`s for separators; then per-row `ToolButton`s go-up/go-down (`Accessible.name: i18n("Move up")` / `i18n("Move down")`, `onClicked: root.moveMember(index, -1 or 1)`) and list-remove; and for non-separator rows an icon edit `ToolButton` (`icon.name: "document-edit"`, `Accessible.name: i18n("Change icon for %1", memberName)`) opening a `PlasmaComponents.Menu` with three `MenuItem`s exactly mirroring the single host's `appIconMenu` (`package/contents/ui/ConfigGeneral.qml:714-729`): `i18n("Choose icon…")` → `root.chooseIcon(modelData, false)`, `i18n("Choose image…")` → `root.chooseIcon(modelData, true)`, `i18n("Reset icon")` (enabled when an override exists) → `root.setCustomIcon(modelData, "")`. Under the list, a `RowLayout` with `PlasmaComponents.Button` `text: i18n("Add application…")` (`icon.name: "list-add"`, enabled when `< 2000`, `onClicked: { appPicker.exclude = settings.applications; appPicker.openPicker() }`) and `i18n("Add separator")` (`onClicked: root.addSeparator()`). Host the `AppPickerDialog { id: appPicker; applications: root.catalog; onPicked: id => root.addMember(id) }` at the root level. `onCountChanged`-style empty-state `PlasmaComponents.Label` `i18n("Add an application or a separator below.")` centered when the list is empty.

**Live-folder page** — `Kirigami.FormLayout` mirroring the group host's folder column (`package-group/contents/ui/ConfigGeneral.qml:410-442`): a `PlasmaComponents.Button` `i18n("Choose folder…")` + read-only path `TextField` (`text: settings.folderUrl`, `placeholderText: i18n("No folder selected")`), a patterns `TextField` (`Accessible.name: i18n("File patterns")`, `placeholderText: i18n("File patterns, for example *.pdf;*.docx")`, `text: settings.folderFilters || "*"`, `onTextEdited: root.setField("folderFilters", text)`), and the helper label `i18n("Separate patterns with semicolons. Subfolders are always shown. Live Folder uses icons and text.")`. Root-level `Dialogs.FolderDialog { id: folderPicker; onAccepted: { const url = selectedFolder.toString(); if (!url.startsWith("file:///")) { root.folderError = i18n("Live Folder currently supports local folders only.") } else { root.folderError = ""; root.setField("folderUrl", url) } } }` with `property string folderError: ""` on the root displayed above the helper.

**Categories page** — `ColumnLayout`: helper `i18n("Match any selected category:")`, then `CategoryChipBar { categories: ApplicationCategories.available(catalog, settings.applicationCategories); selected: settings.applicationCategories; caption: i18nc("%1 is a number of applications", "Matches %1 applications. Results are shown in the panel, not editable here.", matchesCount()); onCategoryToggled: (name, on) => root.toggleCategory(name, on) }`. `ApplicationCategories` is a module sibling — import it relatively (`import "ApplicationCategories.js" as ApplicationCategories`) exactly as `package/contents/ui/ConfigGeneral.qml:5` does today.

**Activity page** — `Kirigami.FormLayout` with the four option controls copied from the group host (`package-group/contents/ui/ConfigGeneral.qml:346-366`: Order combo → `setField("activityOrder", ...)`, Limit spin 1–50 → `setField("activityLimit", ...)`, `i18n("Current Activity only")` checkbox → `setField("activityCurrent", ...)`), then the label `i18n("Optional categories (none means all applications):")` and the same `CategoryChipBar` binding as the categories page. Ranking stays dynamic — no editable result list.

- [ ] **Step 4: Run the suite** — Expected: PASS for all `StackSettingsEditorContents` tests plus prior tasks' tests.

- [ ] **Step 5: Run the full gate to catch cross-suite regressions**

```bash
scripts/ci-run.sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
```

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/StackSettingsEditor.qml tests/stack-editor/tst_stacksettings.qml
git commit -m "Fill StackSettingsEditor Contents pages for all four sources"
```

### Task 7: Single host rewrite — open the shared editor directly

**Files:**
- Modify: `package/contents/ui/ConfigGeneral.qml` (full rewrite around the kept blocks)
- Create test: `tests/stack-editor/tst_single_config.qml`

**Interfaces:**
- Produces: config page exposing the same `cfg_*` properties (unchanged names/defaults), `profileSettings()`, `startProfile`/`finishProfile` (export/import only — icon ops move into the shared editor), plus `stackSettings` (readonly synthesized settings object) and `applySettingsChanges(changes)`.
- Consumes: Tasks 1, 3–6 (`StackSettingsEditor`, `AppPickerDialog` via the editor, `StackMembers`).

- [ ] **Step 1: Write the failing tests** — create `tests/stack-editor/tst_single_config.qml`:

```qml
import QtQuick
import QtTest
import "../../package/contents/ui" as Single

Rectangle {
    width: 760; height: 560
    Single.ConfigGeneral { id: page; anchors.fill: parent }
    TestCase {
        name: "SingleHostSharedEditor"
        when: windowShown
        function test_synthesized_settings_match_cfg() {
            page.cfg_groupName = "Work"
            page.cfg_menuSource = "activity"
            page.cfg_applications = ["a.desktop", "tlbstacks-separator:1:Tools"]
            compare(page.stackSettings.groupName, "Work")
            compare(page.stackSettings.menuSource, "activity")
            compare(page.stackSettings.applications, ["a.desktop", "tlbstacks-separator:1:Tools"])
        }
        function test_editor_changes_apply_to_cfg() {
            page.applySettingsChanges({groupName: "Dev", iconsOnly: true, menuIconSize: 30})
            compare(page.cfg_groupName, "Dev")
            compare(page.cfg_iconsOnly, true)
            compare(page.cfg_menuIconSize, 30)
            page.applySettingsChanges({applications: ["x.desktop"], applicationIcons: {"x.desktop": "/img/x.png"}})
            compare(page.cfg_applications, ["x.desktop"])
            compare(page.cfg_applicationIcons, '{"x.desktop":"/img/x.png"}')
        }
        function test_import_staging_still_works() {
            page.pendingProfile = {id: 7, action: "import"}
            page.finishProfile(7, {ok: true, settings: {
                groupName: "Imported", groupIcon: "applications-all", iconsOnly: false,
                menuIconSize: 22, hoverDelay: 250, applications: ["i.desktop"],
                applicationIcons: {}, menuSource: "applications", activityOrder: "recent",
                activityLimit: 10, activityCurrent: false, applicationCategories: [],
                folderUrl: "", folderFilters: "*"}})
            compare(page.cfg_groupName, "Imported")
            compare(page.cfg_applications, ["i.desktop"])
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails** — build + run `tests/stack-editor`. Expected: FAIL — no `stackSettings`/`applySettingsChanges` on the current page.

- [ ] **Step 3: Rewrite the single host.** Keep verbatim from the current `package/contents/ui/ConfigGeneral.qml`: all `cfg_*` property declarations (lines 19-62), the `Launcher` instance (65-73), `profileSettings()` (117-134), export/import dialogs (136-157), `startProfile` (159-164), import half of `finishProfile` (the `pending.action === "import"` branch, 176-195; delete the now-dead `manageIcon` branch), `refreshMissingApplications` (198-203), `loadApplications`/`applicationsModel` (243-303), `Component.onCompleted` (305-308), and the export/import buttons + profile/missing messages (310-337). Delete: the flat form UI (345-487), category frames (489-577), member/search frames (579-808), `setCustomIcon`/`applyIcon`/`chooseIcon`/icon dialogs (75-115, 233-241), separator locals (already replaced in Task 1), `toggleCategory`, `setApplicationSelected`/`moveApplication`/`insertSeparator` (247-288). Add:

```qml
    readonly property var stackSettings: ({
        groupName: cfg_groupName, groupIcon: cfg_groupIcon, iconsOnly: cfg_iconsOnly,
        menuIconSize: cfg_menuIconSize, hoverDelay: cfg_hoverDelay,
        applications: Array.from(cfg_applications || []),
        applicationIcons: IconOverrides.parse(cfg_applicationIcons),
        menuSource: cfg_menuSource, activityOrder: cfg_activityOrder,
        activityLimit: cfg_activityLimit, activityCurrent: cfg_activityCurrent,
        applicationCategories: Array.from(cfg_applicationCategories || []),
        folderUrl: cfg_folderUrl, folderFilters: cfg_folderFilters
    })
    function applySettingsChanges(changes) {
        if ("groupName" in changes) cfg_groupName = changes.groupName
        if ("groupIcon" in changes) cfg_groupIcon = changes.groupIcon
        if ("iconsOnly" in changes) cfg_iconsOnly = changes.iconsOnly
        if ("menuIconSize" in changes) cfg_menuIconSize = changes.menuIconSize
        if ("hoverDelay" in changes) cfg_hoverDelay = changes.hoverDelay
        if ("applications" in changes) cfg_applications = changes.applications
        if ("applicationIcons" in changes) cfg_applicationIcons = JSON.stringify(changes.applicationIcons)
        if ("menuSource" in changes) cfg_menuSource = changes.menuSource
        if ("activityOrder" in changes) cfg_activityOrder = changes.activityOrder
        if ("activityLimit" in changes) cfg_activityLimit = changes.activityLimit
        if ("activityCurrent" in changes) cfg_activityCurrent = changes.activityCurrent
        if ("applicationCategories" in changes) cfg_applicationCategories = changes.applicationCategories
        if ("folderUrl" in changes) cfg_folderUrl = changes.folderUrl
        if ("folderFilters" in changes) cfg_folderFilters = changes.folderFilters
    }

    StackSettingsEditor {
        id: stackEditor
        settings: root.stackSettings
        catalog: root.categoryApplications
        launcher: launcher
        stackIconDefault: root.cfg_groupIconDefault
        onSettingsEdited: root.applySettingsChanges(changes)
    }
```

The page becomes `ColumnLayout` → export/import row + messages + missing-apps label + `stackEditor` filling the rest. `root.categoryApplications` is set by `loadApplications()` (kept verbatim). `profileSettings()` may now return `stackSettings` — keep whichever keeps the export behavior identical (they are the same shape).

- [ ] **Step 4: Run the suite + full gate**

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
scripts/ci-run.sh
```

- [ ] **Step 5: Commit**

```bash
git add package/contents/ui/ConfigGeneral.qml tests/stack-editor/tst_single_config.qml
git commit -m "Open the shared stack editor from the standalone config page"
```

### Task 8: Group host rewrite — preview strip, item tree, shared editor

Per the recording: preview strip (gear header + item icons + add footer, selection-synced), item tree (group root row, expandable stack rows with summary-label children, Add/Up/Down/Remove toolbar), breadcrumb inspector with group page / launcher page / stack page (`StackSettingsEditor`).

**Files:**
- Modify: `package-group/contents/ui/ConfigGeneral.qml` (full rewrite around kept blocks)
- Modify test: `tests/stack-group-runtime/tst_editor.qml`

**Interfaces:**
- Keeps (existing names, so `tst_editor.qml` stays valid): `cfg_groupName`, `cfg_items`/`cfg_itemsDefault`, `decoded`, `pendingProfile`, `finishProfile`, `selectedIndex`, `selectionRequest`, `selectRequestedItem`, `updateStack(changes)`, `nameFor(id)`, `addApplication(id)`, `moveSelected(step)`, profile dialogs + buttons.
- Produces additionally: `selectedItem`, `selectedStack`, `selectedSource` (already exist), `expandedIds` (var map id→bool, tree expansion), `replaceLauncherApp(desktopId)`.
- Consumes: Tasks 1–6 module components; `GroupItems.replaceLauncher` (Task 2).

- [ ] **Step 1: Port/extend tests first.** In `tests/stack-group-runtime/tst_editor.qml`, keep every existing test function (they drive `cfg_items`, `finishProfile`, selection handoff — all retained APIs) and append:

```qml
    function test_source_switch_keeps_settings_roundtrip() {
        editor.cfg_items = Items.encode(Items.addStack([]))
        const id = editor.decoded.items[0].id
        editor.selectedIndex = 0
        editor.updateStack({menuSource: "folder", folderUrl: "file:///tmp", folderFilters: "*.txt"})
        editor.updateStack({menuSource: "applications", applications: ["one.desktop"]})
        editor.updateStack({menuSource: "folder"})
        const settings = editor.decoded.items[0].settings
        compare(settings.folderUrl, "file:///tmp")
        compare(settings.folderFilters, "*.txt")
        compare(settings.applications, ["one.desktop"])
        verify(!Items.decode(editor.cfg_items).error)
    }
    function test_replace_launcher_swaps_app() {
        editor.cfg_items = Items.encode(Items.add(Items.add([], "one.desktop"), "two.desktop"))
        editor.selectedIndex = 0
        editor.replaceLauncherApp("three.desktop")
        compare(editor.decoded.items[0].desktopId, "three.desktop")
        editor.replaceLauncherApp("two.desktop")   // duplicate → no-op
        compare(editor.decoded.items[0].desktopId, "three.desktop")
    }
    function test_forward_version_config_stays_inert() {
        editor.cfg_items = '{"version":99,"items":[]}'
        verify(editor.decoded.error)
        const previous = editor.cfg_items
        editor.selectedIndex = 0
        editor.updateStack({groupName: "Must not apply"})
        compare(editor.cfg_items, previous)
        editor.replaceLauncherApp("one.desktop")
        compare(editor.cfg_items, previous)
        editor.cfg_items = Items.encode(Items.add([], "one.desktop"))
        verify(!editor.decoded.error)
    }
```

- [ ] **Step 2: Run to verify failures** — build + run `tests/stack-group-runtime`. Expected: existing tests PASS against the current host; the three new ones FAIL (`replaceLauncherApp` missing, etc.).

- [ ] **Step 3: Rewrite the group host.** Keep verbatim from `package-group/contents/ui/ConfigGeneral.qml`: `startProfile`/`finishProfile` (20-60), profile dialogs (61-79), `cfg_*`/`decoded`/`pendingProfile` declarations (80-104), the whole `groupSelection` handoff block (85-98 — isolated, unchanged), `folderPicker`/`folderError` (105-118 — the folder dialog moves into `StackSettingsEditor`; keep only the host-side message plumbing if the editor owns the dialog, else keep it here and delete the editor's duplicate — pick one owner: **the shared editor owns its FolderDialog**; remove the host's `folderPicker` and `folderError`), `Launcher` instance (143-147), `Component.onCompleted` (148-151), `nameFor` (152-155), `updateStack`/`changeMember`/`renameSeparator` (119-134 — `changeMember`/`renameSeparator` move into the shared editor; keep only `updateStack`), `addApplication` (156-164 — repurposed: launcher adds come from `AppPickerDialog`; keep the function for the stack-member path or route both through the editor), `moveSelected` (165-169), the InlineMessage for `decoded.error` (205-210), export/import buttons + message labels (170-195). Layout becomes:

```qml
    // Preview strip: the panel, in order. Gear = group settings; + = add menu.
    PlasmaComponents.ScrollView { /* horizontal ListView, height ~ gridUnit*2.75 */ }
    // Item tree: group root ItemDelegate (highlighted when selectedIndex < 0 …
    // NOTE: the group page is selected with a dedicated `groupPage` bool, since
    // selectedIndex -1 currently also means "adding a launcher" — resolve this
    // by making -1 mean the group page and routing adds through dialogs.)
    // … stack rows with expand chevrons (expandedIds), child summary labels via
    // summaryOf(item) { applications → memberName rows; categories → count;
    // activity → order/limit; folder → url }, Add/Up/Down/Remove toolbar }
    // Inspector: breadcrumb label (link → group page) + QQC2.StackLayout of
    //   group page (group name field, export/import buttons, message) /
    //   launcher page (Application combo of catalog → replaceLauncherApp,
    //     caption i18n("A direct launcher. Turn it into a stack with Add in the tree.")) /
    //   stack page: StackSettingsEditor { settings: selectedStack.settings;
    //     catalog: root.catalog; launcher: launcher; stackIconDefault: "applications-all";
    //     onSettingsEdited: changes => root.updateStack(changes) }
    //
    // The tree and the inspector sit inside a QQC2.SplitView (horizontal) with
    // the tree column at SplitView.preferredWidth: Kirigami.Units.gridUnit * 14
    // — this is the design doc's "resizable sidebar" requirement. The
    // inspector's pages scroll independently (Flickable/ListViews inside).
```

Add the new host functions next to the kept `updateStack`/`moveSelected` block:

```qml
    property var expandedIds: ({})   // stack id → bool, tree expansion state
    function replaceLauncherApp(desktopId) {
        if (!selectedItem || selectedItem.type !== "application" || decoded.error) return
        cfg_items = GroupItems.encode(GroupItems.replaceLauncher(decoded.items, selectedItem.id, desktopId))
    }
    function toggleExpanded(id) { const next = Object.assign({}, expandedIds); next[id] = !next[id]; expandedIds = next }
    function summaryOf(item) {
        if (item.type !== "stack") return []
        const s = item.settings
        if (s.menuSource === "applications")
            return (s.applications || []).map(id => StackMembers.isSeparator(id)
                ? i18n("— %1", StackMembers.separatorLabel(id)) : nameFor(id))
        if (s.menuSource === "categories")
            return [i18np("1 category", "%1 categories", (s.applicationCategories || []).length)]
        if (s.menuSource === "activity")
            return [s.activityOrder === "frequent" ? i18n("Most frequent") : i18n("Most recent")]
        return [s.folderUrl ? decodeURIComponent(s.folderUrl) : i18n("No folder selected")]
    }
```

(`nameFor` is kept verbatim; summary children are plain `PlasmaComponents.Label`s — no click handlers — per the "selectable child rows deferred" constraint.)

Selection semantics for the rewrite (recorded behavior): `selectedIndex === -1` → group page; `>= 0` → that item's page. The old "Add launcher sets selectedIndex = -1 + focuses search" flow is replaced by an Add `Menu` (`Application launcher…` → `AppPickerDialog` with `exclude: decoded.items.map(i => i.desktopId).filter(Boolean)` → `GroupItems.add`; `Stack` → `GroupItems.addStack` + select + expand). The tree's expanded child rows are `PlasmaComponents.Label`s (summary text, `opacity: 0.7`, no click handlers). Breadcrumb: `textFormat: Text.StyledText`, `text: "<a href='group'>" + cfg_groupName + "</a>  ›  " + selectedItemName`, `onLinkActivated: selectedIndex = -1`.

- [ ] **Step 4: Run the group suite + full gate**

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
scripts/ci-run.sh
```

Expected: all existing tests still PASS (selection-handoff test untouched), new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add package-group/contents/ui/ConfigGeneral.qml tests/stack-group-runtime/tst_editor.qml
git commit -m "Rebuild the group editor around the shared StackSettingsEditor"
```

### Task 9: Docs + final verification

**Files:**
- Modify: `docs/STACK_GROUPS.md` (editor section: describe the shared editor + strip/tree host, note deferred increments)
- Modify: `docs/CONFIGURATION_DESIGN.md` (mark step 2 delivered; keep deferred list)
- Modify: `docs/FEATURE_TRACKER.md` (add/update the editor-unification entry, statuses)

- [ ] **Step 1: Update the three docs** to describe the shipped structure (strip/tree/inspector, shared editor field names, both hosts' persistence paths) and the explicit deferrals (inherited defaults, panel-icon key, launcher label/icon overrides, selectable child rows, drag handles). Keep the delivery-order section honest: the right-click fix (step 1) is still pending desktop verification on its own branch.

- [ ] **Step 2: Full verification run**

```bash
scripts/ci-run.sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-group-runtime -o -,txt
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$PWD/build/qml" \
    qmltestrunner-qt6 -input tests/stack-editor -o -,txt
```

Expected: `ALL CHECKS PASSED` plus both suites green.

- [ ] **Step 3: Commit**

```bash
git add docs/STACK_GROUPS.md docs/CONFIGURATION_DESIGN.md docs/FEATURE_TRACKER.md
git commit -m "Document the shared stack editor delivery"
```

- [ ] **Step 4: Flag for manual desktop verification (not automatable here):** install both widgets (`cmake --build build/ci --target install` with `TLB_INSTALL_GROUP=ON`, or `kpackagetool6 -t Plasma/Applet -u package[-group]`), open each config dialog, and check: preview strip selection sync, tree expand/collapse, Contents/Appearance on all four kinds in both widgets, icon Choose/Image/Reset round-trips (incl. `manageIcon` from the group widget), Apply/Cancel staging, import/export round-trips.

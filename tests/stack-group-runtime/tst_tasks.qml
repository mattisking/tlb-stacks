import QtQuick
import QtTest
import "../../package-group/contents/ui/ClickMatrix.js" as ClickMatrix

// The left-click decision half of main.qml's task-button routing, extracted
// into ClickMatrix so it runs offscreen, plus the panel-model identity
// stabilization (ClickMatrix.samePanelItems and its handler wiring pattern).
// Mouse delivery (middle-click new instance, wheel stepping, the
// count-refined cycle) needs a real window and stays on the manual feel-test
// checklist.
TestCase {
    id: root
    name: "GroupTaskButtons"

    // Mirrors TaskArea's contract: stateFor is a pure query with safe
    // defaults, the actions return false when the app is not running so the
    // caller falls back to launching, and calls are recorded so tests can pin
    // that deciding never triggers them.
    QtObject {
        id: area
        property int revision: 0
        property var unclaimed: []
        property var states: ({})
        property var actionCalls: []
        function stateFor(desktopId) {
            return desktopId in states ? states[desktopId]
                : {running: false, active: false, minimized: false, count: 0}
        }
        function activate(desktopId) {
            actionCalls.push("activate " + desktopId)
            return stateFor(desktopId).running
        }
        function cycle(desktopId) {
            actionCalls.push("cycle " + desktopId)
            return stateFor(desktopId).running
        }
        function step(desktopId, direction) { actionCalls.push("step " + desktopId) }
        function newInstance(desktopId) {
            actionCalls.push("newInstance " + desktopId)
            return stateFor(desktopId).running
        }
    }

    function test_single_window_matrix() {
        area.states = {"org.kde.konsole.desktop": {running: false, active: false, minimized: false, count: 0}}
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", area), "launch")
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: true, count: 1}}
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", area), "activate")
        area.states = {"org.kde.konsole.desktop": {running: true, active: true, minimized: false, count: 1}}
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", area), "minimize")
    }

    function test_grouped_windows_matrix() {
        // A focused group still decides "minimize"; the delegate refines by
        // count and cycles to the next member via TaskArea.cycle.
        area.states = {"org.kde.konsole.desktop": {running: true, active: true, minimized: false, count: 3}}
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", area), "minimize")
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: false, count: 3}}
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", area), "activate")
    }

    function test_degraded_mode_launches() {
        // taskArea null (disabled or degraded): the widget behaves exactly
        // as a pure launcher.
        compare(ClickMatrix.decideClick("org.kde.konsole.desktop", null), "launch")
    }

    function test_windows_without_desktop_entry_decide_the_same() {
        area.states = {"": {running: true, active: false, minimized: false, count: 1}}
        compare(ClickMatrix.decideClick("", area), "activate")
        area.states = {}
        compare(ClickMatrix.decideClick("", area), "launch")
    }

    function test_unknown_app_is_idle() {
        area.states = {}
        compare(ClickMatrix.decideClick("never-launched.desktop", area), "launch")
    }

    function test_deciding_never_triggers_task_actions() {
        area.states = {"org.kde.konsole.desktop": {running: true, active: true, minimized: false, count: 2}}
        ClickMatrix.decideClick("org.kde.konsole.desktop", area)
        ClickMatrix.decideClick("never-launched.desktop", area)
        ClickMatrix.decideClick("org.kde.konsole.desktop", null)
        compare(area.actionCalls.length, 0)
    }

    function test_same_panel_items_holds_identity_on_live_state() {
        const rows = [{type: "task", desktopId: "a", name: "A", icon: "ic"}]
        compare(ClickMatrix.samePanelItems(rows, rows), true)
        compare(ClickMatrix.samePanelItems([], []), true)
        // Fresh task rows with the same identity/appearance are the same
        // buttons even when live state differs — delegates read that live
        // through taskArea.stateFor, so it must never rebuild them.
        const same = {type: "task", desktopId: "a", name: "A", icon: "ic"}
        for (const state of [{active: true}, {minimized: true}, {count: 7},
                              {active: true, minimized: false, count: 2}])
            compare(ClickMatrix.samePanelItems(rows, [Object.assign({}, same, state)]), true)
    }

    function test_same_panel_items_content_changes() {
        const rows = [{type: "task", desktopId: "a", name: "A", icon: "ic"}]
        const same = {type: "task", desktopId: "a", name: "A", icon: "ic"}
        for (const changed of [{desktopId: "b"}, {name: "B"}, {icon: "other"}])
            verify(!ClickMatrix.samePanelItems(rows, [Object.assign({}, same, changed)]))
        // A window closed or opened changes the panel.
        verify(!ClickMatrix.samePanelItems(rows, []))
        verify(!ClickMatrix.samePanelItems(rows, rows.concat([Object.assign({}, same)])))
        // Order is content: the append zone follows model order.
        const other = {type: "task", desktopId: "b", name: "B", icon: "ic"}
        verify(!ClickMatrix.samePanelItems([other, same], [same, other]))
    }

    function test_same_panel_items_configured_rows_need_identity() {
        // Configured items only get fresh identities on a re-decode, which is
        // a real change; a task row never equals a configured one.
        const items = [{id: "item-1", type: "application", desktopId: "app.desktop"}]
        verify(!ClickMatrix.samePanelItems(items,
            [{id: "item-1", type: "application", desktopId: "app.desktop"}]))
        verify(!ClickMatrix.samePanelItems(items,
            [{type: "task", desktopId: "app.desktop", name: "App", icon: "ic"}]))
        // Reference-equal elements inside a mixed array stay equal, and a
        // reordered one does not.
        const task = {type: "task", desktopId: "t.desktop", name: "T", icon: "ic"}
        compare(ClickMatrix.samePanelItems(items.concat([task]), items.concat([task])), true)
        verify(!ClickMatrix.samePanelItems(items.concat([task]), [task].concat(items)))
    }

    // The wiring pattern main.qml ships: the source re-evaluates into a fresh
    // array on every revision; only a real content change reaches the
    // Repeater as a model write.
    property int taskRevision: 0
    property var configuredRows: [{id: "item-1", type: "application", desktopId: "app.desktop"}]
    property var taskRows: [{type: "task", desktopId: "a", name: "A", icon: "ic"}]
    readonly property var patternSource: {
        taskRevision
        return configuredRows.concat(taskRows)
    }
    property var patternItems: []
    onPatternSourceChanged: {
        if (ClickMatrix.samePanelItems(patternItems, patternSource)) return
        patternItems = patternSource
    }
    property int patternCreated: 0
    Repeater {
        model: root.patternItems
        Item { Component.onCompleted: root.patternCreated++ }
    }

    function test_panel_model_wiring_keeps_buttons_across_revisions() {
        tryCompare(root, "patternCreated", 2)
        const before = patternItems
        const created = patternCreated
        for (let i = 0; i < 3; ++i) {
            // Fresh rows with churning live state, like TaskArea.unclaimed
            // re-evaluating on every revision bump.
            taskRows = [{type: "task", desktopId: "a", name: "A", icon: "ic",
                active: !!(i % 2), minimized: !(i % 2), count: 1 + i}]
            taskRevision++
            wait(10)
        }
        compare(patternItems === before, true)   // same array reference held
        compare(patternCreated, created)         // no delegate rebuild
        // A real content change rebuilds the buttons.
        taskRows = [{type: "task", desktopId: "a", name: "A", icon: "ic"},
            {type: "task", desktopId: "b", name: "B", icon: "ic"}]
        taskRevision++
        tryCompare(root, "patternCreated", created + 3)  // 2 destroyed, 3 created
    }
}

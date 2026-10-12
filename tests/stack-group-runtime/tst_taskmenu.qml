import QtQuick
import QtTest
import com.mattphilmon.tlbstacks as TLB

// Popup delegate task behavior: a running entry activates its window through
// the taskArea instead of launching, an idle entry keeps the launcher path,
// and a null taskArea (degraded module) keeps the pure-launcher menu the
// tst_module suite pins. Mouse delivery needs a real window, so the suite
// runs offscreen like its siblings — TestCase hides its subtree unless made
// visible (the tst_reorder.qml precedent).
TestCase {
    name: "TaskAwareApplicationMenu"
    when: windowShown
    visible: true
    width: 280; height: 240

    QtObject {
        id: backend
        property var calls: []
        // The native menu's "Close" item: the real Launcher emits this when the
        // user picks it, so the routing contract is pinned against the mock.
        signal closeWindowRequested(string desktopId)
        function themeIconAvailable(name) { return true }
        function activateEntry(entry) { calls.push("launch " + entry.id); return true }
        // Mirrors Launcher::showEntryContextMenu(anchor, entry, offerClose):
        // offerClose is the running state the menu uses to add the Close item.
        function showEntryContextMenu(anchor, entry, offerClose) {
            calls.push("menu " + entry.id + " " + offerClose)
        }
    }

    // Mirrors TaskArea's contract (see tst_tasks.qml): stateFor is a pure
    // query with safe defaults, activate/newInstance/close return false when
    // the app is not running so the caller falls back to launching, and calls
    // are recorded so tests can pin the routing.
    QtObject {
        id: area
        property int revision: 0
        property var states: ({})
        property var calls: []
        function stateFor(desktopId) {
            return desktopId in states ? states[desktopId]
                : {running: false, active: false, minimized: false, count: 0}
        }
        function activate(desktopId) {
            calls.push("activate " + desktopId)
            return stateFor(desktopId).running
        }
        function newInstance(desktopId) {
            calls.push("newInstance " + desktopId)
            return stateFor(desktopId).running
        }
        function close(desktopId) {
            calls.push("close " + desktopId)
            return stateFor(desktopId).running
        }
    }

    TLB.ApplicationMenu {
        id: menu
        width: 260; height: 200
        launcher: backend
        taskArea: area
        // Actions no longer gate the menu on their own: a running app is
        // offered the menu even with no published actions (Close only), while
        // an idle entry needs at least one action to have a menu at all.
        entries: [
            {id: "org.kde.konsole.desktop", name: "Konsole", icon: "folder", available: true, isSeparator: false, actions: []},
            {id: "idle.desktop", name: "Idle", icon: "folder", available: true, isSeparator: false, actions: []},
            {id: "actionable.desktop", name: "Actionable", icon: "folder", available: true, isSeparator: false, actions: ["desktopActions"]}
        ]
    }

    // Mirrors both widget roots' wiring (main.qml is a PlasmoidItem and cannot
    // be instantiated here): the launcher's close request closes the matching
    // windows through the taskArea, and is a no-op when the bridge is degraded.
    Connections {
        target: backend
        function onCloseWindowRequested(desktopId) {
            if (!menu.taskArea) return
            menu.taskArea.close(desktopId)
        }
    }

    SignalSpy { id: activatingSpy; target: menu; signalName: "activating" }
    SignalSpy { id: activatedSpy; target: menu; signalName: "activated" }

    function init() {
        area.states = {}
        area.revision++
        area.calls = []
        backend.calls = []
        activatingSpy.clear()
        activatedSpy.clear()
        menu.taskArea = area
    }

    function entryDelegate(id) {
        return findChild(menu, "menuEntry-" + id)
    }

    function test_running_entry_click_activates_the_window() {
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: true, count: 1}}
        area.revision++
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2)
        compare(area.calls, ["activate org.kde.konsole.desktop"])
        compare(backend.calls, [])
        compare(activatingSpy.count, 1)
        compare(activatedSpy.count, 1)
    }

    function test_idle_entry_click_keeps_the_launch_path() {
        const entry = entryDelegate("idle.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2)
        compare(area.calls, ["activate idle.desktop"])
        compare(backend.calls, ["launch idle.desktop"])
        compare(activatingSpy.count, 1)
        compare(activatedSpy.count, 1)
    }

    // The click matrix's popup row: middle-click launches a new window for
    // a running app, launches an idle one, and stays a no-op without a
    // taskArea — ItemDelegate itself never fires on middle press.
    function test_middle_click_on_running_entry_opens_a_new_window() {
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: false, count: 2}}
        area.revision++
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.MiddleButton)
        compare(area.calls, ["newInstance org.kde.konsole.desktop"])
        compare(backend.calls, [])
        compare(activatingSpy.count, 1)
        compare(activatedSpy.count, 1)
    }

    function test_middle_click_on_idle_entry_launches() {
        const entry = entryDelegate("idle.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.MiddleButton)
        compare(area.calls, ["newInstance idle.desktop"])
        compare(backend.calls, ["launch idle.desktop"])
        compare(activatingSpy.count, 1)
        compare(activatedSpy.count, 1)
    }

    function test_middle_click_without_task_area_is_a_no_op() {
        menu.taskArea = null
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.MiddleButton)
        compare(area.calls, [])
        compare(backend.calls, [])
        compare(activatingSpy.count, 0)
        compare(activatedSpy.count, 0)
    }

    function test_null_task_area_keeps_the_pure_launcher_menu() {
        menu.taskArea = null
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        const dot = findChild(entry, "runningDot")
        const badge = findChild(entry, "countBadge")
        verify(dot)
        verify(badge)
        mouseClick(entry, entry.width / 2, entry.height / 2)
        compare(area.calls, [])
        compare(backend.calls, ["launch org.kde.konsole.desktop"])
        compare(activatingSpy.count, 1)
        compare(activatedSpy.count, 1)
        verify(!dot.visible)
        verify(!badge.visible)
    }

    function test_running_dot_and_count_badge_track_live_state() {
        const entry = entryDelegate("org.kde.konsole.desktop")
        const dot = findChild(entry, "runningDot")
        const badge = findChild(entry, "countBadge")
        verify(dot)
        verify(badge)
        area.states = {"org.kde.konsole.desktop": {running: false, active: false, minimized: false, count: 0}}
        area.revision++
        tryVerify(() => !dot.visible)
        verify(!badge.visible)
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: false, count: 3}}
        area.revision++
        tryVerify(() => dot.visible)
        tryVerify(() => badge.visible)
        compare(badge.text, "3")
    }

    // ---- Close action (Icon-Task-Manager semantics) ----
    // The context menu is offered to a running app even when it publishes no
    // actions (Close only), and to an idle entry only when it has actions.
    function test_right_click_on_running_entry_offers_close() {
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: false, count: 1}}
        area.revision++
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.RightButton)
        compare(backend.calls, ["menu org.kde.konsole.desktop true"])
    }

    function test_menu_key_on_running_entry_offers_close() {
        area.states = {"org.kde.konsole.desktop": {running: true, active: false, minimized: false, count: 1}}
        area.revision++
        const entry = entryDelegate("org.kde.konsole.desktop")
        verify(entry)
        entry.forceActiveFocus()
        keyClick(Qt.Key_Menu)
        compare(backend.calls, ["menu org.kde.konsole.desktop true"])
    }

    function test_right_click_on_idle_entry_without_actions_has_no_menu() {
        const entry = entryDelegate("idle.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.RightButton)
        compare(backend.calls, [])
    }

    function test_right_click_on_actionable_idle_entry_offers_no_close() {
        const entry = entryDelegate("actionable.desktop")
        verify(entry)
        mouseClick(entry, entry.width / 2, entry.height / 2, Qt.RightButton)
        compare(backend.calls, ["menu actionable.desktop false"])
    }

    // Both widget roots route the launcher's close request to the taskArea
    // (null-guarded, so a degraded widget is a no-op).
    function test_close_window_request_routes_to_the_task_area() {
        backend.closeWindowRequested("org.kde.konsole.desktop")
        compare(area.calls, ["close org.kde.konsole.desktop"])
    }

    function test_close_window_request_without_a_task_area_is_a_no_op() {
        menu.taskArea = null
        backend.closeWindowRequested("org.kde.konsole.desktop")
        compare(area.calls, [])
    }
}

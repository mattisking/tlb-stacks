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
        function themeIconAvailable(name) { return true }
        function activateEntry(entry) { calls.push("launch " + entry.id); return true }
        function showEntryContextMenu(anchor, entry) {}
    }

    // Mirrors TaskArea's contract (see tst_tasks.qml): stateFor is a pure
    // query with safe defaults, activate returns false when the app is not
    // running so the caller falls back to launching, and calls are recorded
    // so tests can pin the routing.
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
    }

    TLB.ApplicationMenu {
        id: menu
        width: 260; height: 200
        launcher: backend
        taskArea: area
        entries: [
            {id: "org.kde.konsole.desktop", name: "Konsole", icon: "folder", available: true, isSeparator: false, actions: []},
            {id: "idle.desktop", name: "Idle", icon: "folder", available: true, isSeparator: false, actions: []}
        ]
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
}

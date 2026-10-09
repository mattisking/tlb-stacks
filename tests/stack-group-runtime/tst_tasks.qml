import QtQuick
import QtTest
import "../../package-group/contents/ui/ClickMatrix.js" as ClickMatrix

// The left-click decision half of main.qml's task-button routing, extracted
// into ClickMatrix so it runs offscreen. Mouse delivery (middle-click new
// instance, wheel stepping, the count-refined cycle) needs a real window and
// stays on the manual feel-test checklist.
TestCase {
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
}

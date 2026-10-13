// Loaded only via Loader; import failure degrades to launcher-only mode.
// This is the only file that may import org.kde.taskmanager: a static import
// in either main.qml would make the whole widget fail to load wherever the
// taskmanager module is unavailable.
pragma ComponentBehavior: Bound

import QtQuick
import com.mattphilmon.tlbstacks
import org.kde.taskmanager 0.1 as TaskManager

Item {
    id: root

    // Desktop IDs the widget itself claims; every task outside this set shows
    // up in `unclaimed` for the append zone.
    property var desktopIds: []

    // True whenever this bridge is live. Degraded mode is taskArea === null
    // in consumers (the Loader failed), not available: false.
    readonly property bool available: true

    // Mirrors index.revision, bumped on every tasks-model or desktopIds
    // change. Consumer bindings that call the functions below must reference
    // this property so they re-evaluate when task state changes.
    readonly property int revision: index.revision

    // {type:"task", desktopId, name, icon, active, minimized, count} rows,
    // ready to concat onto a Repeater model. Rows with no resolvable desktop
    // entry (desktopId: "") pass through unchanged.
    readonly property var unclaimed: {
        // Reading index.revision here makes the binding re-run whenever the
        // index bumps it; the value itself is unused.
        index.revision
        return index.unclaimedTasks().map(task => Object.assign({ type: "task" }, task))
    }

    // {running, active, minimized, count, iconName}; safe defaults when
    // nothing matches.
    function stateFor(desktopId) {
        return index.taskState(desktopId)
    }

    // false when the app is not running — the caller falls back to launching.
    function activate(desktopId) {
        return index.activate(desktopId)
    }

    function cycle(desktopId) {
        return index.cycle(desktopId)
    }

    function step(desktopId, direction) {
        index.step(desktopId, direction)
    }

    function newInstance(desktopId) {
        return index.newInstance(desktopId)
    }

    // Politely close every window of the app; false when the app is not
    // running (nothing to close).
    function close(desktopId) {
        return index.close(desktopId)
    }

    // Per-window rows for the app {uuid, winId, title, minimized, active}, for
    // the hover tooltip's live window tiles (empty when not running).
    function windows(desktopId) {
        return index.windows(desktopId)
    }

    // Drive exactly the window a tile names (Wayland uuid or X11 winId).
    function activateWindow(id) {
        return index.activateWindow(id)
    }

    function closeWindow(id) {
        return index.closeWindow(id)
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupApplications
    }

    TaskIndex {
        id: index
        model: tasksModel
        desktopIds: root.desktopIds
    }
}

.pragma library

// The left-click decision for a live task button, per the spec's click matrix:
// a not-running app launches, a running unfocused one activates, and the
// focused one minimizes — a focused group of windows cycles to its next
// member instead, which the caller refines by count. Pure state inspection:
// this never triggers task actions, so it stays testable offscreen. A null
// taskArea (disabled or degraded) decides "launch".
function decideClick(desktopId, taskArea) {
    if (!taskArea)
        return "launch"
    const state = taskArea.stateFor(desktopId)
    if (!state || !state.running)
        return "launch"
    return state.active ? "minimize" : "activate"
}

// Does this panel button own a native app context menu? Direct application
// launchers and auto-appended running-app buttons do (published desktop
// actions, plus Close while the app has live windows); stacks and custom
// command launchers (tlbstacks-command: ids) do not — no KService, no task
// match. Pure inspection, so it stays testable offscreen.
function offersContextMenu(item) {
    return !!item && (item.type === "application" || item.type === "task")
}

// Do two panel arrays render the same buttons? Cheap content comparison for
// the identity-stabilized panel model: a reference match is always equal, and
// fresh unclaimed rows (TaskArea re-maps them on every revision) compare by
// desktopId + position. Live state (active/minimized/count) is deliberately
// excluded — delegates read that live through taskArea.stateFor — so an
// unrelated focus change never rebuilds the buttons. name and icon are
// excluded too: a single-window app's name is its WINDOW TITLE, churning on
// every tab switch, and name/icon feed only tooltip/accessible text on the
// icon-only buttons — a stale-until-membership-change title is accepted so
// title churn never closes a popup or rebuilds the panel. Configured items
// only get fresh identities on a re-decode, which is a real change, so they
// compare by reference alone.
function samePanelItems(a, b) {
    if (a === b)
        return true
    if (!a || !b || a.length !== b.length)
        return false
    for (let i = 0; i < a.length; ++i) {
        const x = a[i], y = b[i]
        if (x === y)
            continue
        if (!x || !y || x.type !== "task" || y.type !== "task" || x.desktopId !== y.desktopId)
            return false
    }
    return true
}

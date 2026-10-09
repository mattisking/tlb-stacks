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

// Do two panel arrays render the same buttons? Cheap content comparison for
// the identity-stabilized panel model: a reference match is always equal, and
// fresh unclaimed rows (TaskArea re-maps them on every revision) compare by
// their identity/appearance fields. Live state (active/minimized/count) is
// deliberately excluded — delegates read that live through taskArea.stateFor —
// so an unrelated focus change never rebuilds the buttons. Configured items
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
        if (!x || !y || x.type !== "task" || y.type !== "task"
            || x.desktopId !== y.desktopId || x.name !== y.name || x.icon !== y.icon)
            return false
    }
    return true
}

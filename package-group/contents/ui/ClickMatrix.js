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

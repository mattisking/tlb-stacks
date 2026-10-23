.pragma library

// The group bar's layout arithmetic, kept pure so it is testable offscreen. The
// gap between buttons follows the panel's own spacing: the panel view spaces its
// applets with min(theme margin + smallSpacing,
// floor(max(1, thickness - iconSizes.smallMedium) / 2)) — the theme's small
// spacing, tightened on a panel too short to afford it
// (org.kde.plasma.desktop/contents/views/Panel.qml). The bar has no theme margin
// of its own, so it takes the same cap on the same theme value. Every button kind
// (launcher, stack, appended task) shares the one row, so they all get this gap.

// The gap between two neighbouring buttons, from the thickness the bar is drawn in
// (`cellSize` is the panel thickness on a horizontal panel), the theme's small
// spacing and the icon size the panel's own formula measures against. Never zero:
// adjacent buttons must stay visually separate at any panel size.
function barButtonSpacing(cellSize, smallSpacing, iconSize) {
    const thickness = Number(cellSize) || 0
    const icon = Number(iconSize) || 0
    const cap = Math.floor(Math.max(1, thickness - icon) / 2)
    const theme = Number(smallSpacing) || 0
    return Math.max(1, Math.min(Math.round(theme * 1.5), cap))
}

// The bar's extent along its long axis: every button cell, plus one gap between
// each neighbouring pair (so a single button carries no gap, and none at all
// yields nothing to draw).
function barLength(count, cellSize, spacing) {
    const buttons = Math.max(0, Math.floor(Number(count) || 0))
    if (buttons === 0)
        return 0
    const cell = Math.max(0, Number(cellSize) || 0)
    const gap = Math.max(0, Number(spacing) || 0)
    return buttons * cell + (buttons - 1) * gap
}

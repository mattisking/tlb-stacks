.pragma library

// Tooltip decisions for a running app, kept pure so they are testable offscreen
// (the live thumbnail backends — PipeWire on Wayland, WindowThumbnail on X11 —
// are verified on a real session instead).

// Which tip a hover shows: an app with live windows gets the tile view, anything
// else keeps the plain text tooltip.
function showsTiles(windows) {
    return !!(windows && windows.length)
}

// The identifier one tile drives: the platform's per-window id as the string
// TaskIndex::activateWindow/closeWindow take — a Wayland UUID or an X11 WId.
// Empty when the model exposed neither, so the tile cannot be driven.
function windowId(win) {
    if (!win)
        return ""
    return win.uuid ? win.uuid : (win.winId ? String(win.winId) : "")
}

// What a tile interaction means: the ✕ button and the middle button close the
// window, anything else activates it. Null when the tile has no id.
function tileRequest(win, button) {
    const id = windowId(win)
    if (!id)
        return null
    return {action: button === "middle" || button === "close" ? "close" : "activate", id: id}
}

// Are the tooltip's window tiles instantiated right now? The dialog refuses to
// show an empty mainItem, so the content is armed from the moment the tip starts
// arming and stays armed through the show. It is cleared only when the tip
// hides, so nothing — delegates, thumbnails, PipeWire requests — exists while
// nothing is hovered; text tips never arm tiles.
// `armRequested` must stay true while the pre-show pause runs AND when that
// one-shot pause stops: a Timer's `running` flips false before `onTriggered`
// executes, so keying the arm off it would tear the content down on the way to
// the show (the empty-dialog path).
function tilesArmed(tileMode, shown, armRequested) {
    return !!tileMode && (!!shown || !!armRequested)
}

// The tile tip's viewport width. The row itself is as wide as its windows, so an
// app with many of them would produce a tip wider than the screen, with the later
// tiles off-screen and out of reach. The viewport is therefore capped at half the
// screen span — never below one tile, so a single tile is always shown whole — and
// the row scrolls horizontally inside it. An unusable screen reading keeps the
// natural row rather than guessing a cap. Zero windows collapse to nothing (the
// tip is on its text branch).
function tilesWidth(windowCount, tileWidth, tileSpacing, screenSpan) {
    const count = Math.max(0, Number(windowCount) || 0)
    const natural = count * tileWidth + Math.max(0, count - 1) * tileSpacing
    const span = Number(screenSpan)
    const cap = isFinite(span) ? Math.max(tileWidth, Math.round(span / 2)) : natural
    return Math.min(natural, cap)
}

// Where one wheel turn leaves the tile viewport: the offset moves by the wheel's
// delta (both axes summed by the caller) and stops at either end of the row. A row
// that already fits its viewport has no offset to move to, so it can never drift,
// and an unusable reading leaves the row where it is rather than throwing it
// somewhere arbitrary.
function scrollTarget(currentContentX, wheelDelta, contentWidth, viewportWidth) {
    const current = Number(currentContentX) || 0
    const delta = Number(wheelDelta) || 0
    const max = Math.max(0, (Number(contentWidth) || 0) - (Number(viewportWidth) || 0))
    return Math.min(Math.max(current + delta, 0), max)
}

// The dialog draws frame margins around its mainItem, so its window size is the
// content plus those margins. A theme that reports nothing yet (or a NaN reading)
// counts as zero: the window must never fall below the content, or the tip would
// clip its own tiles.
function dialogSize(contentWidth, contentHeight, marginLeft, marginRight, marginTop, marginBottom) {
    const atLeastZero = value => {
        const number = Number(value)
        return isFinite(number) && number > 0 ? number : 0
    }
    return {width: atLeastZero(contentWidth) + atLeastZero(marginLeft) + atLeastZero(marginRight),
            height: atLeastZero(contentHeight) + atLeastZero(marginTop) + atLeastZero(marginBottom)}
}

// The x for a natively positioned tip: horizontally centred on its anchor item and
// clamped into the screen rectangle. `windowWidth` is the CURRENT window width, so
// the centre is recomputed after every correction — a tip that shrank must not keep
// the far-left x a wider geometry left behind, and the dialog does not re-anchor for
// a size we wrote ourselves.
function centeredX(anchorX, anchorWidth, windowWidth, screenX, screenWidth) {
    const centred = anchorX + (anchorWidth - windowWidth) / 2
    return Math.min(Math.max(centred, screenX), Math.max(screenX, screenX + screenWidth - windowWidth))
}

// Which kind of window does this tip need? A clickable tile tip has to receive
// pointer input, and the tooltip window kind does not reliably deliver button
// events on every platform, so an interactive tip is an ordinary frameless,
// non-focusable tool window. A text tip stays a pure, input-free tooltip.
function tipWindowKind(interactive) {
    return interactive ? "tool" : "tooltip"
}

// Should the tip hide? Text tips hide the moment the anchor loses the pointer.
// Tile tips stay up while the pointer is over them, and their caller waits out the
// transit grace (transitGraceMs) before asking, so a move from the anchor onto a
// tile survives the dead band between the two. This is deliberately a *hide*
// decision rather than a bound "is visible" expression: hover state depends on the
// dialog being visible, so a bound expression that read hover would both hide the
// tip the instant the pointer left the anchor and loop through the window's
// visibility.
function shouldHide(ready, interactive, tipHovered) {
    if (ready)
        return false
    if (!interactive)
        return true
    return !tipHovered
}

// How long the tip keeps its place after the pointer leaves the anchor. Only the
// dead band between the two rectangles matters — once the pointer is over the tip,
// hover takes over and the grace is moot — and it is crossed at a deliberately
// slow pointer speed (px per millisecond). Floored so an adjacent anchor/tip still
// gets a usable grace, and capped so no geometry can pin the tip on screen.
function transitGraceMs(gapPx, speedPxPerMs, minMs, maxMs) {
    const needed = Math.ceil(Math.max(0, gapPx) / speedPxPerMs)
    return Math.min(Math.max(needed, minMs), maxMs)
}

// Should the tip flip visible now? The armed content must have stopped changing
// size first, so the dialog resizes — and, for natively anchored tips, re-anchors
// against the panel — while it is still invisible, making the first visible frame
// final size and final position. `attempts` bounds the wait, so a thumbnail that
// never arrives (a minimized window never streams) cannot stall the tip.
function shouldShow(width, height, previousWidth, previousHeight, attempts, maxAttempts) {
    if (attempts >= maxAttempts)
        return true
    return width > 0 && height > 0 && width === previousWidth && height === previousHeight
}

// Does this tip hand its positioning to Plasma? Bar tips ("above") anchor to the
// hovered button at the panel's edge via the Dialog's native machinery, which
// screen-clamps and re-anchors on resize. Popup tips ("beside") are placed
// manually by the tooltip.
function usesNativePlacement(placement) {
    return placement === "above"
}

// Manual tooltip placement for popup ("beside") tips, in global screen
// coordinates: the tip goes past the host window's right edge (flipping left)
// when that fits, centred vertically on the hovered row, clamped into the screen
// rectangle. An oversized tip pins to the screen origin instead of escaping it.
function placeTip(anchorX, anchorY, anchorW, anchorH, tipW, tipH,
                  screenX, screenY, screenW, screenH) {
    const gap = 8
    const right = screenX + screenW
    const bottom = screenY + screenH
    const clampY = value => Math.min(Math.max(value, screenY), Math.max(screenY, bottom - tipH))

    const besideRight = anchorX + anchorW + gap
    return {x: besideRight + tipW <= right ? besideRight : Math.max(screenX, anchorX - tipW - gap),
            y: clampY(anchorY + (anchorH - tipH) / 2)}
}

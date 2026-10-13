import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "TaskWindows.js" as TaskWindows

Item {
    id: root
    required property string text
    required property bool selected
    // Live windows of a running app ({uuid, winId, title, minimized, active});
    // a non-empty list swaps the plain text tip for one tile per window.
    property var windows: []
    // Icon for a minimized window, or while no live thumbnail is available.
    property string fallbackIcon: "application-x-executable"
    // "beside" (default) keeps the popup-entry behaviour: the tip sits past the
    // host window's right edge, placed manually. Panel buttons use "above" —
    // there the host window is the full-width panel, so the tip is handed to
    // Plasma, anchored to the button at the panel's edge.
    property string placement: "beside"
    // Panel location for natively positioned tips (the bar passes
    // Plasmoid.location); Floating keeps the Dialog out of the way when the
    // tooltip places itself.
    property int dialogLocation: PlasmaCore.Types.Floating
    property bool shown: false
    readonly property var hostWindow: root.Window.window
    readonly property bool ready: selected && hostWindow !== null && hostWindow.visible
    readonly property bool tileMode: TaskWindows.showsTiles(root.windows)
    // Armed from the hover until the tip hides, so the dialog is already sized
    // when it becomes visible and the content can never be torn down on the way
    // to the show.
    property bool armRequested: false
    readonly property bool tilesActive: TaskWindows.tilesArmed(tileMode, shown, armRequested)
    // Only the tile tip takes the pointer; the text tip stays output-only so it
    // can never cause a hover-leave/show feedback loop.
    readonly property bool interactive: tileMode
    property bool tipHovered: false
    // The dead band between the anchor and the tip, measured from their global
    // rectangles: the pointer crosses it with neither surface seeing it, so the
    // grace has to cover that crossing.
    readonly property real transitGap: {
        const anchorPos = root.mapToGlobal(0, 0)
        const dx = Math.max(0, Math.max(anchorPos.x - (tip.x + tip.width),
                                              tip.x - (anchorPos.x + root.width)))
        const dy = Math.max(0, Math.max(anchorPos.y - (tip.y + tip.height),
                                              tip.y - (anchorPos.y + root.height)))
        return Math.sqrt(dx * dx + dy * dy)
    }
    // Bar tips let Plasma position them against the panel edge (clamped and
    // re-anchored natively on resize); popup tips place themselves manually.
    readonly property bool nativePositioning: TaskWindows.usesNativePlacement(root.placement)
    // One window tile: a title header over a 16:10 preview box. The geometry is
    // fixed and computed here rather than taken from the positioners: a hidden
    // QQuickWindow never lays its content out, so a Row's implicit size is 0 until
    // the dialog is shown — the dialog would size itself from 0, appear empty, and
    // then resize (dragging a natively anchored tip out of place). The first
    // visible frame is final only if the size never depends on layout.
    readonly property int tileSpacing: Math.round(Kirigami.Units.largeSpacing / 2)
    readonly property int tileWidth: Math.round(Kirigami.Units.gridUnit * 12)
    readonly property int previewHeight: Math.round(tileWidth * 0.625)
    readonly property int tileHeaderHeight: Math.round(Kirigami.Units.gridUnit * 1.6)
    readonly property int tileHeight: tileHeaderHeight + previewHeight
    readonly property int tilesWidth: root.windows.length > 0
        ? root.windows.length * tileWidth + (root.windows.length - 1) * tileSpacing : 0
    // The no-thumbnail fallback is a modest centred icon, not a full-bleed
    // image: the preview box keeps its geometry either way, so a failed or
    // minimized stream never resizes the tile (and never re-runs placement).
    readonly property int fallbackIconSize: Math.max(48, Math.round(Kirigami.Units.gridUnit * 2.5))
    // Turns spent waiting for the armed content to settle before the flip (see
    // TaskWindows.shouldShow). Measured: a tile tip's size is already final while
    // the dialog is still hidden, so one deferred turn is enough for the dialog to
    // take that size; the second is spare, and the cap means a late size change
    // can never stall the tip.
    readonly property int maxSettleAttempts: 2

    signal windowActivated(string id)
    signal windowClosed(string id)

    function hideToolTip() {
        pause.stop()
        hoverHide.stop()
        shown = false
        armRequested = false
    }
    function restart() {
        hideToolTip()
        if (ready && (text.length > 0 || tileMode)) {
            armRequested = true
            pause.restart()
        }
    }
    function placeTip() {
        // Bar tips are positioned natively; manual x/y would fight the Dialog's
        // own anchoring and produce the resize/reposition flashing.
        if (root.nativePositioning) return
        const host = root.hostWindow
        if (!host) return
        const row = root.mapToGlobal(0, 0)
        const placed = TaskWindows.placeTip(host.x, row.y, host.width, root.height,
            tip.width, tip.height, root.Screen.virtualX, root.Screen.virtualY,
            root.Screen.width, root.Screen.height)
        tip.x = placed.x
        tip.y = placed.y
    }
    // The tile row grows as delegates and thumbnails size themselves, so the
    // placement has to be re-run until the content settles.
    function replaceIfShown() {
        if (!root.shown) return
        Qt.callLater(function() { if (root.shown) root.placeTip() })
    }
    // The dialog adopts its size once, at the show flip, and never follows the
    // content afterwards — so a payload that grows or shrinks while the tip is up (a
    // window opening or closing under a hover, or the model's regroup transition)
    // would render clipped, with the extra tiles outside the window. While shown the
    // window is therefore sized explicitly from the content, and the resulting
    // resize re-runs the native anchoring.
    function applyWindowSize() {
        const content = tip.mainItem
        if (!root.shown || !content)
            return
        const margins = tip.margins || {}
        const size = TaskWindows.dialogSize(content.implicitWidth, content.implicitHeight,
            margins.left, margins.right, margins.top, margins.bottom)
        if (tip.width !== size.width)
            tip.width = size.width
        if (tip.height !== size.height)
            tip.height = size.height
    }
    // Content settled (or changed) while the tip is up: keep the window in step and
    // re-place the manually positioned ("beside") tips.
    function contentChanged() {
        root.applyWindowSize()
        root.replaceIfShown()
    }
    // Flip visible: the size is final by now, so the first visible frame is
    // already at the right size and place.
    function flipVisible() {
        root.placeTip()
        root.shown = true
        // The native frame margins are final only after the window is shown: apply
        // the settled size and re-place once the frame is real.
        Qt.callLater(function() {
            if (!root.shown) return
            root.applyWindowSize()
            root.placeTip()
        })
    }
    // The armed content has to finish a layout pass before the dialog flips
    // visible: showing earlier puts the first frame at a pre-settle size, and the
    // resize that follows later drags a natively anchored tip out of place. Wait
    // for the main item's implicit size to stop changing (bounded).
    function settleThenShow(attempts, previousWidth, previousHeight) {
        if (!root.ready || root.shown || !root.armRequested) return
        const content = tip.mainItem
        const width = content ? content.implicitWidth : 0
        const height = content ? content.implicitHeight : 0
        if (TaskWindows.shouldShow(width, height, previousWidth, previousHeight, attempts, root.maxSettleAttempts)) {
            root.flipVisible()
            return
        }
        Qt.callLater(function() { root.settleThenShow(attempts + 1, width, height) })
    }
    function driveTile(win, button) {
        const request = TaskWindows.tileRequest(win, button)
        if (!request) return
        if (request.action === "close") root.windowClosed(request.id)
        else root.windowActivated(request.id)
    }

    onReadyChanged: {
        if (ready) {
            restart()
            return
        }
        if (!root.interactive) {
            // A text tip hides the moment the anchor loses the pointer.
            hideToolTip()
            return
        }
        // Tile tip: arm the transit grace first — the pointer may be crossing the
        // dead band between the anchor and the tip — and let the grace firing (and a
        // hover onto the tip) decide through TaskWindows.shouldHide. The interval is
        // measured here, not bound: the dialog repositions itself when it shows, so
        // a bound interval would put this timer's running state in a binding loop.
        hoverHide.interval = TaskWindows.transitGraceMs(root.transitGap, 0.5, 250, 600)
        hoverHide.restart()
    }
    onTextChanged: restart()
    // The pointer left the tiles while the anchor is also un-hovered: hide (a move
    // back onto the tiles keeps them up through the grace instead).
    onTipHoveredChanged: if (TaskWindows.shouldHide(root.ready, root.interactive, root.tipHovered))
        hideToolTip()
    Component.onCompleted: restart()
    Component.onDestruction: hideToolTip()

    Timer {
        id: pause
        interval: 700
        onTriggered: {
            if (!root.ready) return
            // The text tip is sized synchronously, so it flips straight away. A
            // tile tip waits for its armed content to settle first, so the first
            // visible frame is final size and final position.
            if (!root.tileMode) {
                root.flipVisible()
                return
            }
            root.settleThenShow(0, 0, 0)
        }
    }
    Timer {
        id: hoverHide
        // Interval is set when the transit starts (see onReadyChanged): the grace
        // covers the dead band between the anchor and the tip, and a hover onto the
        // tip cancels it.
        onTriggered: if (TaskWindows.shouldHide(root.ready, root.interactive, root.tipHovered))
            root.hideToolTip()
    }
    PlasmaCore.Dialog {
        id: tip
        transientParent: root.hostWindow
        // On screen exactly while it is shown: showing and hiding are imperative
        // (flipVisible/hideToolTip) so that hover state — which itself depends on
        // the window being visible — is never part of this binding.
        visible: root.shown
        // Natively positioned tips anchor to the hovered item and take the
        // panel's location: Plasma then places them against the panel edge,
        // clamps them to the screen, and re-anchors them on resize.
        visualParent: root.nativePositioning ? root : null
        location: root.nativePositioning ? root.dialogLocation : PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.Tooltip
        // See TaskWindows.tipWindowKind: the clickable tile tip must be an
        // interactive surface (a tooltip-kind window does not reliably deliver
        // button events), while the text tip stays a pure, input-free tooltip.
        flags: TaskWindows.tipWindowKind(root.interactive) === "tool"
            ? Qt.Tool | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
            : Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        // Tiles are clickable, so the tile tip accepts the pointer; the text tip
        // never intercepts it.
        outputOnly: !root.interactive
        hideOnWindowDeactivate: false
        mainItem: Item {
            // The text tip keeps its 320px cap (the label's own width clamp);
            // tiles use the fixed geometry above, so the dialog has its final size
            // while still hidden and the first visible frame needs no resize.
            implicitWidth: root.tilesActive ? root.tilesWidth : Math.min(textLabel.implicitWidth, 320)
            implicitHeight: root.tilesActive ? root.tileHeight : textLabel.implicitHeight
            // Tiles settle a frame or two after the dialog shows; re-place then, and
            // keep the window in step when the content changes while shown.
            onImplicitWidthChanged: root.contentChanged()
            onImplicitHeightChanged: root.contentChanged()

            HoverHandler {
                id: tipHover
                enabled: root.interactive
                onHoveredChanged: root.tipHovered = hovered
            }
            Row {
                id: tileRow
                visible: root.tilesActive
                // Explicit, not implicit: no layout pass required for the size.
                width: root.tilesWidth
                height: root.tileHeight
                spacing: root.tileSpacing
                Repeater {
                    model: root.tilesActive ? root.windows : []
                    delegate: Item {
                        id: tile
                        required property var modelData
                        readonly property bool live: modelData.minimized !== true
                            && ((modelData.winId || 0) > 0 || !!modelData.uuid)
                        width: root.tileWidth
                        height: root.tileHeight

                        // Fixed-geometry preview box: the tile and tip sizes
                        // never depend on whether a live thumbnail is available.
                        Item {
                            id: previewBox
                            anchors.top: headerRow.bottom
                            width: parent.width
                            height: root.previewHeight

                            // Fallback: a modest centred icon, not a full-bleed
                            // image (a minimized window, no live thumbnail backend,
                            // or a session where the Wayland backend cannot even be
                            // loaded — see the loader below).
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: root.fallbackIconSize
                                height: root.fallbackIconSize
                                source: root.fallbackIcon
                                visible: !tile.live || waylandThumb.unavailable
                            }
                            // X11: Plasma's window pixmap. Sized by the box, never
                            // by its own implicit size, so the pixmap arriving can
                            // never resize the tile or move the dialog.
                            PlasmaCore.WindowThumbnail {
                                width: previewBox.width
                                height: previewBox.height
                                visible: tile.live && (tile.modelData.winId || 0) > 0
                                winId: tile.modelData.winId || 0
                            }
                            // Wayland: PipeWire stream fed by the window UUID and
                            // likewise box-sized, so a stream arriving after the
                            // show swaps in place without moving anything.
                            Loader {
                                id: waylandThumb
                                width: previewBox.width
                                height: previewBox.height
                                // Loaded BY URL, never as an inline Component:
                                // TaskThumbnail.qml imports org.kde.taskmanager and
                                // org.kde.pipewire, and an inline component is compiled
                                // together with this file, so in a session without
                                // those modules merely compiling the tooltip would take
                                // every consumer of it down. By URL their imports are
                                // resolved only when this loader actually activates.
                                property bool unavailable: false
                                active: !unavailable && root.shown && tile.live
                                    && (tile.modelData.winId || 0) === 0 && !!tile.modelData.uuid
                                source: unavailable ? "" : "TaskThumbnail.qml"
                                // A module-less session can never load it: latch the
                                // failure so we stop retrying (one log line, not one
                                // per hover) and the tile keeps its icon fallback.
                                onStatusChanged: if (status === Loader.Error) unavailable = true
                                onLoaded: if (item) item.uuid = Qt.binding(() => tile.modelData.uuid)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: mouse => root.driveTile(tile.modelData,
                                mouse.button === Qt.MiddleButton ? "middle" : "left")
                        }
                        // Declared last so the ✕ gets its clicks before the tile.
                        // Fixed header band, so the preview box below it sits at a
                        // computed offset rather than a laid-out one.
                        Row {
                            id: headerRow
                            width: parent.width
                            height: root.tileHeaderHeight
                            spacing: Kirigami.Units.smallSpacing
                            PlasmaComponents.Label {
                                width: Math.max(0, headerRow.width - closeButton.width - headerRow.spacing)
                                height: headerRow.height
                                verticalAlignment: Text.AlignVCenter
                                text: tile.modelData.title || i18n("Untitled window")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                color: tile.modelData.active === true
                                    ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            }
                            PlasmaComponents.ToolButton {
                                id: closeButton
                                height: headerRow.height
                                icon.name: "window-close"
                                Accessible.name: i18n("Close window")
                                onClicked: root.driveTile(tile.modelData, "close")
                            }
                        }
                    }
                }
            }
            PlasmaComponents.Label {
                id: textLabel
                visible: !root.tileMode
                text: root.text
                textFormat: Text.PlainText
                font: Kirigami.Theme.smallFont
                width: Math.min(implicitWidth, 320)
                height: implicitHeight
                wrapMode: Text.Wrap
            }
        }
    }
}

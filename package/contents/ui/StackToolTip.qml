import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: root
    required property string text
    required property bool selected
    property bool shown: false
    readonly property var hostWindow: root.Window.window
    readonly property bool ready: selected && hostWindow !== null && hostWindow.visible

    function hideToolTip() {
        pause.stop()
        shown = false
    }
    function restart() {
        hideToolTip()
        if (ready && text.length > 0) pause.restart()
    }
    function placeTip() {
        const host = root.hostWindow
        if (!host) return
        const row = root.mapToGlobal(0, 0)
        const left = root.Screen.virtualX
        const top = root.Screen.virtualY
        const right = left + root.Screen.width
        const bottom = top + root.Screen.height
        const besideRight = host.x + host.width + 8
        const besideLeft = host.x - tip.width - 8
        tip.x = besideRight + tip.width <= right ? besideRight
            : Math.max(left, besideLeft)
        tip.y = Math.max(top, Math.min(row.y + (root.height - tip.height) / 2,
                                      bottom - tip.height))
    }
    onReadyChanged: restart()
    onTextChanged: restart()
    Component.onCompleted: restart()
    Component.onDestruction: hideToolTip()

    Timer {
        id: pause
        interval: 700
        onTriggered: {
            if (!root.ready) return
            root.placeTip()
            root.shown = true
            // The native frame margins are final only after the window is shown.
            Qt.callLater(function() { if (root.shown) root.placeTip() })
        }
    }
    PlasmaCore.Dialog {
        id: tip
        transientParent: root.hostWindow
        visible: root.shown && root.ready
        type: PlasmaCore.Dialog.Tooltip
        location: PlasmaCore.Types.Floating
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        // Never intercept the pointer and cause a hover-leave/show feedback loop.
        outputOnly: true
        hideOnWindowDeactivate: false
        mainItem: PlasmaComponents.Label {
            text: root.text
            textFormat: Text.PlainText
            font: Kirigami.Theme.smallFont
            width: Math.min(implicitWidth, 320)
            height: implicitHeight
            wrapMode: Text.Wrap
        }
    }
}

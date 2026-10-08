import QtQuick
import org.kde.kirigami as Kirigami

// Gesture state only: hosts retain ownership of their models and save semantics.
Item {
    id: root
    required property ListView view
    parent: view
    property string draggingId: ""
    property int boundary: -1
    property real pointerX: 0
    property real pointerY: 0
    property real lineY: 0
    readonly property bool active: draggingId.length > 0
    signal moveRequested(string itemId, int destination)
    function cancel() { draggingId = ""; boundary = -1 }
    function update(x, y) {
        pointerX = x; pointerY = y; boundary = -1
        if (!active || x < 0 || x > view.width || y < 0 || y > view.height) return
        const contentY = y + view.contentY
        const index = view.indexAt(view.width / 2, contentY)
        if (index >= 0) {
            const row = view.itemAtIndex(index)
            if (!row) return
            const after = contentY >= row.y + row.height / 2
            boundary = index + (after ? 1 : 0)
            lineY = row.y + (after ? row.height : 0)
        } else if (contentY < view.originY + (view.headerItem ? view.headerItem.height : 0)) {
            boundary = 0
            lineY = view.originY + (view.headerItem ? view.headerItem.height : 0)
        } else if (contentY >= view.originY + view.contentHeight) {
            boundary = view.count
            lineY = view.originY + view.contentHeight
        }
    }
    function finish() {
        const id = draggingId
        const destination = boundary
        cancel()
        if (id && destination >= 0) moveRequested(id, destination)
    }
    Connections {
        target: root.view
        function onVisibleChanged() { if (!root.view.visible) root.cancel() }
        function onModelChanged() { root.cancel() }
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.active
        onActivated: root.cancel()
    }
    Timer {
        interval: 30
        repeat: true
        running: root.active
        onTriggered: {
            const y = root.pointerY
            if (root.pointerX < 0 || root.pointerX > root.view.width || y < 0 || y > root.view.height) return
            const margin = Kirigami.Units.gridUnit * 2
            const step = y < margin ? -8 : y > root.view.height - margin ? 8 : 0
            if (!step) return
            root.view.contentY = Math.max(root.view.originY,
                Math.min(root.view.originY + Math.max(0, root.view.contentHeight - root.view.height), root.view.contentY + step))
            root.update(root.pointerX, y)
        }
    }
    Rectangle {
        parent: root.view.contentItem
        z: 10
        width: root.view.width
        height: 2
        y: root.lineY - 1
        color: Kirigami.Theme.highlightColor
        visible: root.active && root.boundary >= 0
    }
}

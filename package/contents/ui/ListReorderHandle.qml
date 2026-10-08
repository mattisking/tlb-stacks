import QtQuick
import org.kde.kirigami as Kirigami

MouseArea {
    id: root
    required property ListReorderController controller
    required property string itemId
    required property string label
    implicitWidth: Kirigami.Units.gridUnit * 1.5
    implicitHeight: Kirigami.Units.gridUnit * 2
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    preventStealing: true
    property real pressY: 0
    property bool started: false
    onPressed: mouse => { pressY = mouse.y; started = false }
    onPositionChanged: mouse => {
        if (!pressed) return
        if (!started && Math.abs(mouse.y - pressY) >= 8) {
            started = true
            controller.draggingId = itemId
        }
        if (!controller.active) return
        const point = mapToItem(controller.view, mouse.x, mouse.y)
        controller.update(point.x, point.y)
    }
    onReleased: controller.finish()
    onCanceled: controller.cancel()
    Accessible.name: qsTr("Drag to reorder %1").arg(label)
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.small
        height: width
        source: "transform-move"
        opacity: root.pressed ? 1 : 0.55
    }
}

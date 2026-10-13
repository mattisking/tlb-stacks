// Wayland live window thumbnail: a PipeWire stream fed by the window's UUID
// through TaskManager's ScreencastingRequest. These two imports are the reason
// this lives in its own component — the tooltip loads it through a Loader, so a
// session without the pipewire/taskmanager modules degrades to the icon
// fallback instead of failing the whole widget.
import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire

Item {
    id: root
    required property string uuid

    readonly property int nodeId: request.nodeId
    // Until the compositor hands over a node there is nothing to paint; the
    // tile's icon fallback shows through.
    visible: nodeId !== 0

    TaskManager.ScreencastingRequest {
        id: request
        uuid: root.uuid
    }
    PipeWire.PipeWireSourceItem {
        anchors.fill: parent
        nodeId: root.nodeId
    }
}

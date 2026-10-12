import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

RowLayout {
    id: root
    property string spinObjectName: "launcherIconSize"
    property int value: 0
    property string automaticLabel: qsTr("Use group setting")
    signal edited(int size)
    QQC2.CheckBox {
        text: root.automaticLabel
        checked: root.value === 0
        onToggled: root.edited(checked ? 0 : 32)
    }
    QQC2.SpinBox {
        objectName: root.spinObjectName
        from: 16
        to: 64
        editable: true
        live: true
        visible: root.value !== 0
        enabled: root.value !== 0
        value: root.value || 32
        Accessible.name: qsTr("Panel icon size in pixels")
        onValueChanged: if (enabled && value !== root.value) root.edited(value)
    }
    QQC2.Label { visible: root.value !== 0; text: qsTr("px") }
}

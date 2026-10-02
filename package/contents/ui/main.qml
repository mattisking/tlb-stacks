import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import com.mattphilmon.truelaunchbar

PlasmoidItem {
    id: root

    Plasmoid.icon: "applications-all"

    toolTipMainText: "True Launch Bar"
    toolTipSubText: "Development"

    Launcher {
        id: launcher
    }

    property var applications: [
        "com.microsoft.VSCode",
        "org.kde.dolphin",
        "org.mozilla.firefox"
    ]

    fullRepresentation: Item {
        Layout.minimumWidth: 360
        Layout.minimumHeight: 140
        Layout.preferredWidth: 360
        Layout.preferredHeight: 140

        RowLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.applications

                delegate: PlasmaComponents.ToolButton {
                    required property string modelData

                    visible: launcher.exists(modelData)

                    text: launcher.name(modelData)

                    display: PlasmaComponents.AbstractButton.TextUnderIcon

                    icon.name: launcher.icon(modelData)

                    onClicked: {
                        if (launcher.launch(modelData)) {
                            root.expanded = false
                        }
                    }
                }
            }
        }
    }
}
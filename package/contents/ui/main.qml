import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    Plasmoid.icon: "applications-all"

    toolTipMainText: "True Launch Bar"
    toolTipSubText: "Application group"

    fullRepresentation: Item {
        Layout.minimumWidth: 300
        Layout.minimumHeight: 180
        Layout.preferredWidth: 300
        Layout.preferredHeight: 180

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: "applications-all"
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents.Label {
                text: "True Launch Bar"
                Layout.alignment: Qt.AlignHCenter
            }

            PlasmaComponents.Label {
                text: "It lives!"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}

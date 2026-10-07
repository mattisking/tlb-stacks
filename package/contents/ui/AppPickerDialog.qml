import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Searchable application picker shown only while adding (review note:
// search takes space only when adding). Emits picked(desktopId).
QQC2.Dialog {
    id: root

    property var applications: []
    property var exclude: []
    signal picked(string desktopId)

    modal: true
    title: i18n("Add application")
    standardButtons: QQC2.Dialog.Cancel
    anchors.centerIn: parent
    width: Math.min(Kirigami.Units.gridUnit * 28, (parent ? parent.width : 600) - Kirigami.Units.gridUnit * 2)
    height: Math.min(Kirigami.Units.gridUnit * 28, (parent ? parent.height : 500) - Kirigami.Units.gridUnit * 2)

    function openPicker() {
        search.text = ""
        open()
        search.forceActiveFocus()
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.TextField {
            id: search
            objectName: "pickerSearch"
            Layout.fillWidth: true
            placeholderText: i18n("Search applications…")
            clearButtonShown: true
            Keys.onReturnPressed: event => { event.accepted = true }
            Keys.onEnterPressed: event => { event.accepted = true }
        }
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            ListView {
                id: list
                clip: true
                model: {
                    const query = search.text.toLowerCase()
                    return root.applications.filter(app =>
                        !root.exclude.includes(app.desktopId) &&
                        app.name.toLowerCase().includes(query))
                }
                delegate: PlasmaComponents.ItemDelegate {
                    id: row
                    required property var modelData
                    objectName: "pick-" + modelData.desktopId
                    width: ListView.view.width
                    text: modelData.name
                    icon.name: modelData.icon || "application-x-executable"
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    onClicked: { root.picked(modelData.desktopId); root.close() }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: list.count === 0
                    text: search.text.length > 0 ? i18n("No applications match your search.")
                        : i18n("Every application is already in this stack.")
                }
            }
        }
    }
}

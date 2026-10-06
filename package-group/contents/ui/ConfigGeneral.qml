pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import com.mattphilmon.tlbstacks
import "GroupItems.js" as GroupItems

ColumnLayout {
    id: root
    property string title: i18n("General")
    property alias cfg_groupName: groupNameField.text
    property string cfg_groupNameDefault: ""
    property string cfg_items: '{"version":1,"items":[]}'
    property string cfg_itemsDefault: '{"version":1,"items":[]}'
    readonly property var decoded: GroupItems.decode(cfg_items)
    property var catalog: []
    property int selectedIndex: -1
    Launcher {
        id: launcher
        onApplicationsChanged: root.catalog = launcher.applications()
    }
    Component.onCompleted: catalog = launcher.applications()
    function nameFor(id) {
        const app = catalog.find(app => app.desktopId === id)
        return app ? app.name : i18n("%1 (unavailable)", id)
    }
    function addApplication(id) {
        cfg_items = GroupItems.encode(GroupItems.add(decoded.items, id))
        selectedIndex = decoded.items.length - 1
    }
    function moveSelected(step) {
        const index = selectedIndex
        cfg_items = GroupItems.encode(GroupItems.move(decoded.items, index, step))
        selectedIndex = index + step
    }
    Kirigami.FormLayout {
        Layout.fillWidth: true
        PlasmaComponents.TextField {
            id: groupNameField
            Kirigami.FormData.label: i18n("Group name:")
            placeholderText: i18n("TLBStacks Group")
            maximumLength: 256
        }
    }
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: root.decoded.error
        type: Kirigami.MessageType.Error
        text: i18n("These group settings cannot be edited by this version. They have been preserved; cancel and use a compatible version.")
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        enabled: !root.decoded.error
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            PlasmaComponents.Label { text: i18n("Launchers in panel order"); font.bold: true }
            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 220
                contentWidth: availableWidth
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ListView {
                    id: selectedList
                    clip: true
                    model: root.decoded.items
                    currentIndex: root.selectedIndex
                    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                    Keys.onDownPressed: root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1)
                    delegate: PlasmaComponents.ItemDelegate {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        text: root.nameFor(modelData.desktopId)
                        highlighted: root.selectedIndex === index
                        onClicked: { root.selectedIndex = index; selectedList.forceActiveFocus() }
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        visible: selectedList.count === 0
                        text: i18n("Add applications from the search list.")
                    }
                }
            }
            RowLayout {
                PlasmaComponents.ToolButton {
                    icon.name: "go-up"
                    Accessible.name: i18n("Move up")
                    enabled: root.selectedIndex > 0
                    onClicked: root.moveSelected(-1)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "go-down"
                    Accessible.name: i18n("Move down")
                    enabled: root.selectedIndex >= 0 && root.selectedIndex < root.decoded.items.length - 1
                    onClicked: root.moveSelected(1)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "list-remove"
                    Accessible.name: i18n("Remove selected launcher")
                    enabled: root.selectedIndex >= 0 && root.selectedIndex < root.decoded.items.length
                    onClicked: {
                        const index = root.selectedIndex
                        root.cfg_items = GroupItems.encode(GroupItems.remove(root.decoded.items, index))
                        root.selectedIndex = Math.min(index, root.decoded.items.length - 1)
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            PlasmaComponents.TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: i18n("Search applications…")
                clearButtonShown: true
                Keys.onReturnPressed: event => { event.accepted = true }
                Keys.onEnterPressed: event => { event.accepted = true }
            }
            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 220
                contentWidth: availableWidth
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ListView {
                    clip: true
                    model: root.catalog.filter(app => app.name.toLowerCase().includes(search.text.toLowerCase())
                        && !root.decoded.items.some(item => item.desktopId === app.desktopId))
                    delegate: RowLayout {
                        id: appRow
                        required property var modelData
                        width: ListView.view.width
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: appRow.modelData.name
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "list-add"
                            enabled: root.decoded.items.length < 500
                            Accessible.name: i18n("Add %1", appRow.modelData.name)
                            onClicked: root.addApplication(appRow.modelData.desktopId)
                        }
                    }
                }
            }
        }
    }
}

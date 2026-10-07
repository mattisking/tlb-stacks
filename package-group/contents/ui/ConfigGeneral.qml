pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
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
    readonly property var selectedItem: decoded.items[selectedIndex] || null
    readonly property var selectedStack: selectedItem && selectedItem.type === "stack" ? selectedItem : null
    function updateStack(changes) {
        if (selectedStack) cfg_items = GroupItems.encode(GroupItems.updateStack(decoded.items, selectedStack.id, changes))
    }
    function changeMember(index, step, remove) {
        const apps = selectedStack.settings.applications.slice()
        if (remove) apps.splice(index, 1)
        else apps.splice(index + step, 0, apps.splice(index, 1)[0])
        updateStack({applications: apps})
    }
    function renameSeparator(stackId, separatorId, label) {
        const stack = decoded.items.find(item => item.id === stackId && item.type === "stack")
        if (!stack) return
        cfg_items = GroupItems.encode(GroupItems.updateStack(decoded.items, stackId, {
            applications: GroupItems.renameSeparator(stack.settings.applications, separatorId, label)
        }))
    }
    IconThemes.IconDialog {
        id: iconDialog
        property string targetId: ""
        onIconNameChanged: {
            if (iconName && targetId)
                root.cfg_items = GroupItems.encode(GroupItems.updateStack(root.decoded.items, targetId, {groupIcon: iconName}))
        }
    }
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
        if (selectedStack) {
            if (!selectedStack.settings.applications.includes(id))
                updateStack({applications: selectedStack.settings.applications.concat([id])})
        } else {
            cfg_items = GroupItems.encode(GroupItems.add(decoded.items, id))
            selectedIndex = decoded.items.length - 1
        }
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
            PlasmaComponents.Label { text: i18n("Items in panel order"); font.bold: true }
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
                        text: modelData.type === "stack" ? (modelData.settings.groupName || i18n("Stack")) + " ▸"
                            : root.nameFor(modelData.desktopId)
                        highlighted: root.selectedIndex === index
                        onClicked: { root.selectedIndex = index; selectedList.forceActiveFocus() }
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        visible: selectedList.count === 0
                        text: i18n("Add a stack or an application launcher.")
                    }
                }
            }
            RowLayout {
                PlasmaComponents.Button {
                    text: i18n("Add stack")
                    enabled: root.decoded.items.length < 500
                    onClicked: {
                        root.cfg_items = GroupItems.encode(GroupItems.addStack(root.decoded.items))
                        root.selectedIndex = root.decoded.items.length - 1
                    }
                }
                PlasmaComponents.Button {
                    text: i18n("Add launcher")
                    onClicked: { root.selectedIndex = -1; search.forceActiveFocus() }
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
            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.selectedStack ? i18n("Selected Applications stack") : i18n("Add a direct application launcher")
                font.bold: true
            }
            PlasmaComponents.TextField {
                Layout.fillWidth: true
                visible: root.selectedStack !== null
                placeholderText: i18n("Stack name")
                text: root.selectedStack ? root.selectedStack.settings.groupName : ""
                onTextEdited: root.updateStack({groupName: text})
            }
            RowLayout {
                visible: root.selectedStack !== null
                PlasmaComponents.Button {
                    text: i18n("Choose icon…")
                    icon.name: root.selectedStack ? root.selectedStack.settings.groupIcon : "applications-all"
                    onClicked: { iconDialog.targetId = root.selectedStack.id; iconDialog.open() }
                }
                PlasmaComponents.CheckBox {
                    text: i18n("Icons only")
                    checked: root.selectedStack ? root.selectedStack.settings.iconsOnly : false
                    onToggled: root.updateStack({iconsOnly: checked})
                }
            }
            RowLayout {
                visible: root.selectedStack !== null
                PlasmaComponents.Label { text: i18n("Icon size:") }
                QQC2.SpinBox {
                    from: 16; to: 64
                    value: root.selectedStack ? root.selectedStack.settings.menuIconSize : 22
                    onValueModified: root.updateStack({menuIconSize: value})
                }
                PlasmaComponents.Label { text: i18n("Hover delay:") }
                QQC2.SpinBox {
                    from: 0; to: 2000; stepSize: 50
                    value: root.selectedStack ? root.selectedStack.settings.hoverDelay : 250
                    onValueModified: root.updateStack({hoverDelay: value})
                }
            }
            PlasmaComponents.Button {
                visible: root.selectedStack !== null
                text: i18n("Add separator")
                icon.name: "list-add"
                enabled: root.selectedStack && root.selectedStack.settings.applications.length < 2000
                onClicked: root.updateStack({applications: GroupItems.appendSeparator(root.selectedStack.settings.applications)})
            }
            PlasmaComponents.ScrollView {
                visible: root.selectedStack !== null
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                contentWidth: availableWidth
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ListView {
                    clip: true
                    model: root.selectedStack ? root.selectedStack.settings.applications : []
                    delegate: RowLayout {
                        id: member
                        required property string modelData
                        required property int index
                        width: ListView.view.width
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: !GroupItems.isSeparator(member.modelData)
                            text: root.nameFor(member.modelData)
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.TextField {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: GroupItems.isSeparator(member.modelData)
                            property string editStackId: ""
                            property string editSeparatorId: ""
                            text: GroupItems.separatorLabel(member.modelData)
                            placeholderText: i18n("Separator label (optional)")
                            Accessible.name: i18n("Separator label")
                            maximumLength: 64
                            onActiveFocusChanged: if (activeFocus && root.selectedStack) {
                                editStackId = root.selectedStack.id
                                editSeparatorId = member.modelData
                            }
                            onEditingFinished: root.renameSeparator(editStackId, editSeparatorId, text)
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "go-up"
                            Accessible.name: i18n("Move up")
                            enabled: member.index > 0
                            onClicked: root.changeMember(member.index, -1, false)
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "go-down"
                            Accessible.name: i18n("Move down")
                            enabled: root.selectedStack && member.index < root.selectedStack.settings.applications.length - 1
                            onClicked: root.changeMember(member.index, 1, false)
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "list-remove"
                            Accessible.name: i18n("Remove from stack")
                            onClicked: root.changeMember(member.index, 0, true)
                        }
                    }
                }
            }
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
                        && !(root.selectedStack ? root.selectedStack.settings.applications.includes(app.desktopId)
                            : root.decoded.items.some(item => item.type === "application" && item.desktopId === app.desktopId)))
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
                            enabled: root.selectedStack ? root.selectedStack.settings.applications.length < 2000 : root.decoded.items.length < 500
                            Accessible.name: i18n("Add %1", appRow.modelData.name)
                            onClicked: root.addApplication(appRow.modelData.desktopId)
                        }
                    }
                }
            }
        }
    }
}

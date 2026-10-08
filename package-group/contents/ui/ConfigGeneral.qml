pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
import org.kde.plasma.components as PlasmaComponents
import com.mattphilmon.tlbstacks
import "GroupItems.js" as GroupItems

ColumnLayout {
    id: root
    property string title: i18n("General")
    enabled: !launcher.profileBusy
    property var pendingProfile: null
    property string profileMessage: ""
    function startProfile(action, request, targetId, memberId) {
        if (launcher.profileBusy) return
        pendingProfile = {id: launcher.profileOperation(action, request), action: action, targetId: targetId || "", memberId: memberId || ""}
        profileMessage = i18n("Working… Please wait before applying changes.")
    }
    function finishProfile(requestId, result) {
        if (!pendingProfile || pendingProfile.id !== requestId) return
        const action = pendingProfile.action
        const targetId = pendingProfile.targetId
        const memberId = pendingProfile.memberId || ""
        pendingProfile = null
        if (!result.ok) { profileMessage = result.error; return }
        if (action === "manageIcon") {
            if (memberId) applyMemberIcon(targetId, memberId, result.icon)
            else updateLauncherAppearance(targetId, {icon: result.icon})
            profileMessage = ""
            return
        }
        if (action !== "importGroup") {
            profileMessage = i18n("Exported with custom images and portable folder references.")
            return
        }
        selectedMemberId = ""
        if (result.kind === "group") {
            const encoded = GroupItems.encode(result.group.items)
            if (GroupItems.decode(encoded).error) {
                profileMessage = i18n("This group requires a newer editor. Current settings were preserved.")
                return
            }
            cfg_items = encoded
            cfg_panelIconSize = result.group.panelIconSize || 0
            cfg_groupName = result.group.groupName
            selectedIndex = decoded.items.length ? 0 : -1
            profileMessage = i18n("Group loaded into the editor. Apply to replace this group's contents, or Cancel to keep them.")
        } else {
            if (decoded.error || decoded.items.length >= 500) {
                profileMessage = i18n("Cannot add a stack: the current group is invalid or full.")
                return
            }
            const encoded = GroupItems.encode(GroupItems.appendImportedStack(decoded.items, result.settings))
            if (GroupItems.decode(encoded).error) {
                profileMessage = i18n("This stack requires a newer editor. Current settings were preserved.")
                return
            }
            cfg_items = encoded
            selectedIndex = decoded.items.length - 1
            profileMessage = i18n("Stack added to the editor. Apply to save, or Cancel to keep the previous group.")
        }
        if (result.folderMissing)
            profileMessage += "\n" + i18n("One or more imported folders are unavailable. Review their locations before applying.")
    }
    Dialogs.FileDialog {
        id: importDialog
        title: i18n("Import a stack or group into the editor")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("TLBStacks profile (*.zip)")]
        onAccepted: root.startProfile("importGroup", {file: selectedFile.toString()})
    }
    Dialogs.FileDialog {
        id: exportDialog
        property bool wholeGroup: true
        property var exportSettings: ({})
        title: wholeGroup ? i18n("Export group") : i18n("Export selected stack")
        fileMode: Dialogs.FileDialog.SaveFile
        defaultSuffix: "zip"
        nameFilters: [i18n("TLBStacks profile (*.zip)")]
        onAccepted: root.startProfile(wholeGroup ? "exportGroup" : "export", wholeGroup
            ? {file: selectedFile.toString(), group: {groupName: root.cfg_groupName, panelIconSize: root.cfg_panelIconSize, items: root.decoded.items}}
            : {file: selectedFile.toString(), settings: exportSettings})
    }
    property int cfg_panelIconSize: 0
    property int cfg_panelIconSizeDefault: 0
    property alias cfg_groupName: groupNameField.text
    property string cfg_groupNameDefault: ""
    property string cfg_items: '{"version":1,"items":[]}'
    property string cfg_itemsDefault: '{"version":1,"items":[]}'
    onCfg_itemsChanged: cancelItemDrag()
    readonly property var decoded: GroupItems.decode(cfg_items)
    property var catalog: []
    // Selection: -1 shows the group page; >= 0 shows that item's page. Adds
    // route through the add menu's dialogs, so -1 never means "adding".
    property int selectedIndex: -1
    property string selectedMemberId: ""
    property string selectedMemberStackId: ""
    onSelectedIndexChanged: selectedMemberId = ""
    readonly property bool memberSelected: !!selectedStack && selectedStack.id === selectedMemberStackId
        && selectedStack.settings.menuSource === "applications" && selectedMemberId.length > 0
        && !StackMembers.isSeparator(selectedMemberId) && selectedStack.settings.applications.includes(selectedMemberId)
    function selectMember(index, desktopId) {
        const item = decoded.items[index]
        if (!item || item.type !== "stack" || item.settings.menuSource !== "applications"
            || StackMembers.isSeparator(desktopId) || !item.settings.applications.includes(desktopId)) return
        selectedIndex = index
        selectedMemberStackId = item.id
        selectedMemberId = desktopId
    }
    function applyMemberIcon(stackId, desktopId, icon) {
        const item = decoded.items.find(entry => entry.id === stackId && entry.type === "stack")
        if (!item || item.settings.menuSource !== "applications" || !item.settings.applications.includes(desktopId)) return
        const icons = Object.assign({}, item.settings.applicationIcons || {})
        if (icon) icons[desktopId] = icon
        else delete icons[desktopId]
        cfg_items = GroupItems.encode(GroupItems.updateStack(decoded.items, stackId, {applicationIcons: icons}))
    }
    function chooseMemberIcon(fromFile) {
        if (!memberSelected) return
        launcherIconTarget = selectedStack.id
        iconTargetMember = selectedMemberId
        if (fromFile) launcherImageDialog.open()
        else { launcherIconDialog.title = i18n("Choose an application icon"); launcherIconDialog.open() }
    }
    readonly property var selectedItem: decoded.items[selectedIndex] || null
    readonly property var selectedStack: selectedItem && selectedItem.type === "stack" ? selectedItem : null
    readonly property string selectedSource: selectedStack ? selectedStack.settings.menuSource : ""
    readonly property var categoryNames: ApplicationCategories.available(catalog,
        selectedStack ? selectedStack.settings.applicationCategories : [])
    function updateStack(changes) {
        if (selectedStack) cfg_items = GroupItems.encode(GroupItems.updateStack(decoded.items, selectedStack.id, changes))
    }
    Launcher {
        id: launcher
        onApplicationsChanged: root.catalog = launcher.applications()
        onProfileFinished: (requestId, result) => root.finishProfile(requestId, result)
    }
    Component.onCompleted: catalog = launcher.applications()
    function nameFor(id) {
        const custom = selectedStack ? (selectedStack.settings.customLaunchers || {})[id] : null
        if (custom) return custom.name
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
    function updateLauncherAppearance(id, changes) {
        if (!decoded.error) cfg_items = GroupItems.encode(GroupItems.updateLauncherAppearance(decoded.items, id, changes))
    }
    function launcherLabel(item) { return item.label || (item.type === "command" ? item.command.name : nameFor(item.desktopId)) }
    function launcherIcon(item) {
        return item.icon || (catalog.find(app => app.desktopId === item.desktopId) || {}).icon || "application-x-executable"
    }
    property string launcherIconTarget: ""
    property string iconTargetMember: ""
    function chooseLauncherIcon(fromFile) {
        if (!selectedItem || !["application", "command"].includes(selectedItem.type)) return
        launcherIconTarget = selectedItem.id
        iconTargetMember = ""
        if (fromFile) launcherImageDialog.open()
        else {
            launcherIconDialog.title = i18n("Choose a launcher icon")
            launcherIconDialog.open()
        }
    }
    IconThemes.IconDialog {
        id: launcherIconDialog
        onIconNameChanged: if (iconName.length) root.startProfile("manageIcon", {icon: iconName}, root.launcherIconTarget, root.iconTargetMember)
    }
    Dialogs.FileDialog {
        id: launcherImageDialog
        title: i18n("Choose a launcher image")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("Icon images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.ico)")]
        onAccepted: root.startProfile("manageIcon", {icon: selectedFile.toString()}, root.launcherIconTarget, root.iconTargetMember)
    }
    function moveSelected(step) {
        const index = selectedIndex
        cfg_items = GroupItems.encode(GroupItems.move(decoded.items, index, step))
        selectedIndex = index + step
    }
    readonly property string draggingItemId: treeReorder.draggingId
    readonly property int dropBoundary: treeReorder.boundary
    function cancelItemDrag() { treeReorder.cancel() }
    ListReorderController {
        id: treeReorder
        view: itemTree
        onMoveRequested: (itemId, destination) => root.reorderItem(itemId, destination)
    }
    function reorderItem(id, boundary) {
        const items = decoded.items.slice()
        const from = items.findIndex(item => item.id === id)
        if (decoded.error || from < 0 || boundary < 0 || boundary > items.length) return
        const to = boundary > from ? boundary - 1 : boundary
        if (to === from) return
        const selectedId = selectedItem ? selectedItem.id : ""
        const memberId = selectedMemberId
        items.splice(to, 0, items.splice(from, 1)[0])
        cfg_items = GroupItems.encode(items)
        selectedIndex = items.findIndex(item => item.id === selectedId)
        selectedMemberId = memberId
    }
    property var expandedIds: ({})   // stack id → bool, tree expansion state
    function replaceLauncherApp(desktopId) {
        if (!selectedItem || selectedItem.type !== "application" || decoded.error) return
        cfg_items = GroupItems.encode(GroupItems.replaceLauncher(decoded.items, selectedItem.id, desktopId))
    }
    function toggleExpanded(id) {
        const next = Object.assign({}, expandedIds)
        next[id] = !next[id]
        expandedIds = next
        if (!next[id] && selectedMemberStackId === id) selectedMemberId = ""
    }
    function summaryOf(item) {
        if (item.type !== "stack") return []
        const s = item.settings
        if (s.menuSource === "applications")
            return (s.applications || []).map(id => StackMembers.isSeparator(id)
                ? i18n("— %1", StackMembers.separatorLabel(id)) : (s.customLaunchers || {})[id] ? s.customLaunchers[id].name : nameFor(id))
        if (s.menuSource === "categories")
            return [i18np("1 category", "%1 categories", (s.applicationCategories || []).length)]
        if (s.menuSource === "activity")
            return [s.activityOrder === "frequent" ? i18n("Most frequent") : i18n("Most recent")]
        return [s.folderUrl ? decodeURIComponent(s.folderUrl) : i18n("No folder selected")]
    }
    readonly property string selectedItemName: !selectedItem ? ""
        : selectedItem.type === "stack" ? (selectedItem.settings.groupName || i18n("Stack"))
        : launcherLabel(selectedItem)
    // The breadcrumb renders as Text.StyledText, so imported names must be
    // escaped before entering the markup: an imported "<img src=…>" name
    // would otherwise become a live (remotely-fetchable) image tag.
    function escapeHtml(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // Launcher adds come through the shared picker (stack-member adds have
    // their own picker inside StackSettingsEditor).
    AppPickerDialog {
        id: launcherPicker
        applications: root.catalog
        onPicked: id => {
            if (root.decoded.error) return
            root.cfg_items = GroupItems.encode(GroupItems.add(root.decoded.items, id))
            root.selectedIndex = root.decoded.items.length - 1
        }
    }
    function savePanelCommand(id, name, executable, argumentsText) {
        const parsed = StackMembers.parseArguments(argumentsText)
        if (decoded.error || parsed.error) return
        const items = GroupItems.saveCommand(decoded.items, id, {name: name.trim(), executable: executable, arguments: parsed.arguments})
        cfg_items = GroupItems.encode(items)
        if (!id) selectedIndex = items.length - 1
    }
    CustomLauncherDialog {
        id: panelCommandDialog
        onSaved: (id, name, executable, argumentsText) => root.savePanelCommand(id, name, executable, argumentsText)
    }
    PlasmaComponents.Menu {
        id: addMenu
        PlasmaComponents.MenuItem {
            text: i18n("Custom launcher…")
            icon.name: "list-add"
            enabled: !root.decoded.error && root.decoded.items.length < 500
            onTriggered: panelCommandDialog.edit("", {})
        }
        PlasmaComponents.MenuItem {
            text: i18n("Application launcher…")
            icon.name: "list-add"
            enabled: !root.decoded.error && root.decoded.items.length < 500
            onTriggered: {
                launcherPicker.exclude = root.decoded.items.map(item => item.desktopId).filter(Boolean)
                launcherPicker.openPicker()
            }
        }
        PlasmaComponents.MenuItem {
            text: i18n("Stack")
            icon.name: "list-add"
            enabled: !root.decoded.error && root.decoded.items.length < 500
            onTriggered: {
                root.cfg_items = GroupItems.encode(GroupItems.addStack(root.decoded.items))
                root.selectedIndex = root.decoded.items.length - 1
                const id = root.decoded.items[root.decoded.items.length - 1].id
                if (!root.expandedIds[id]) root.toggleExpanded(id)
            }
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: root.decoded.error
        type: Kirigami.MessageType.Error
        text: i18n("These group settings cannot be edited by this version. They have been preserved; cancel and use a compatible version.")
    }

    // Preview strip: the panel, in order. Gear = group settings; + = add menu.
    ListView {
        id: strip
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.75
        orientation: ListView.Horizontal
        clip: true
        spacing: Kirigami.Units.smallSpacing
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { }
        model: root.decoded.items
        header: PlasmaComponents.ToolButton {
            height: ListView.view.height
            display: QQC2.AbstractButton.IconOnly
            icon.name: "settings-configure"
            text: i18n("Group settings")
            highlighted: root.selectedIndex < 0
            onClicked: root.selectedIndex = -1
            Accessible.name: i18n("Group settings")
        }
        footer: PlasmaComponents.ToolButton {
            id: addFooter
            height: ListView.view.height
            display: QQC2.AbstractButton.IconOnly
            icon.name: "list-add"
            text: i18n("Add")
            enabled: !root.decoded.error && root.decoded.items.length < 500
            onClicked: addMenu.popup(addFooter)
            Accessible.name: i18n("Add")
        }
        delegate: PlasmaComponents.ToolButton {
            id: stripCell
            required property var modelData
            required property int index
            height: ListView.view.height
            display: QQC2.AbstractButton.IconOnly
            readonly property string resolvedIcon: {
                const catalogNow = root.catalog
                return modelData.type === "stack" ? modelData.settings.groupIcon || "applications-all"
                    : root.launcherIcon(modelData)
            }
            icon.name: IconOverrides.isFile(resolvedIcon) ? "" : resolvedIcon
            icon.source: IconOverrides.isFile(resolvedIcon) ? resolvedIcon : ""
            icon.color: "transparent"
            icon.width: Kirigami.Units.iconSizes.medium
            icon.height: Kirigami.Units.iconSizes.medium
            text: modelData.type === "stack"
                ? (modelData.settings.groupName || i18n("Stack")) : root.launcherLabel(modelData)
            highlighted: root.selectedIndex === stripCell.index
            onClicked: { root.selectedMemberId = ""; root.selectedIndex = stripCell.index }
            Accessible.name: stripCell.text
            PlasmaComponents.ToolTip {
                text: stripCell.text
            }
        }
    }

    QQC2.SplitView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        orientation: Qt.Horizontal

        // Left pane: the item tree with its toolbar, then the profile
        // actions. Import/export lives here — not on a page — so it stays
        // visible whichever item is selected. The tree goes inert on an
        // unreadable config, but Import… stays enabled there: importing an
        // older group is the recovery path for forward-version settings.
        ColumnLayout {
            id: treeColumn
            spacing: Kirigami.Units.smallSpacing
            QQC2.SplitView.preferredWidth: Kirigami.Units.gridUnit * 14

            // Item tree: the group's structure, in panel order.
            PlasmaComponents.ScrollView {
                enabled: !root.decoded.error
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ListView {
                    id: itemTree
                    objectName: "itemTree"
                    interactive: !root.draggingItemId
                    // Keep the grabbed delegate alive while edge-scrolling.
                    cacheBuffer: root.draggingItemId ? Math.max(contentHeight, height) : 320
                    clip: true
                    currentIndex: root.selectedIndex
                    model: root.decoded.items
                    Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                    Keys.onDownPressed: root.selectedIndex = Math.min(count - 1, root.selectedIndex + 1)
                    header: PlasmaComponents.ItemDelegate {
                        width: ListView.view.width
                        icon.name: "settings-configure"
                        text: root.cfg_groupName || i18n("Group")
                        highlighted: root.selectedIndex < 0
                        onClicked: { root.selectedIndex = -1; itemTree.forceActiveFocus() }
                    }
                    delegate: ColumnLayout {
                        id: treeRow
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        spacing: 0

                        PlasmaComponents.ItemDelegate {
                            id: itemRow
                            leftPadding: dragHandle.width + Kirigami.Units.smallSpacing
                            readonly property bool isStack: treeRow.modelData.type === "stack"
                            Layout.fillWidth: true
                            text: itemRow.isStack
                                ? (treeRow.modelData.settings.groupName || i18n("Stack"))
                                : root.launcherLabel(treeRow.modelData)
                            readonly property string itemIcon: itemRow.isStack ? treeRow.modelData.settings.groupIcon || "applications-all"
                                : root.launcherIcon(treeRow.modelData)
                            icon.name: IconOverrides.isFile(itemIcon) ? "" : itemIcon
                            icon.source: IconOverrides.isFile(itemIcon) ? itemIcon : ""
                            icon.color: "transparent"
                            highlighted: root.selectedIndex === treeRow.index && !root.memberSelected
                            rightPadding: expandChevron.implicitWidth + Kirigami.Units.smallSpacing * 2
                            onClicked: { root.selectedMemberId = ""; root.selectedIndex = treeRow.index; itemTree.forceActiveFocus() }

                            ListReorderHandle {
                                id: dragHandle
                                objectName: "reorder-" + treeRow.modelData.id
                                controller: treeReorder
                                itemId: treeRow.modelData.id
                                label: itemRow.text
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: implicitWidth
                                height: parent.height
                            }

                            PlasmaComponents.ToolButton {
                                id: expandChevron
                                visible: itemRow.isStack
                                anchors.right: parent.right
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                anchors.verticalCenter: parent.verticalCenter
                                icon.name: root.expandedIds[treeRow.modelData.id] ? "arrow-down" : "arrow-right"
                                Accessible.name: root.expandedIds[treeRow.modelData.id] ? i18n("Collapse") : i18n("Expand")
                                onClicked: root.toggleExpanded(treeRow.modelData.id)
                            }
                        }

                        Repeater {
                            model: itemRow.isStack && root.expandedIds[treeRow.modelData.id]
                                ? root.summaryOf(treeRow.modelData) : []
                            PlasmaComponents.ItemDelegate {
                                id: memberRow
                                objectName: "member-" + treeRow.modelData.id + "-" + desktopId
                                required property string modelData
                                required property int index
                                readonly property string desktopId: treeRow.modelData.settings.menuSource === "applications"
                                    ? treeRow.modelData.settings.applications[index] : ""
                                readonly property bool selectable: desktopId.length > 0 && !StackMembers.isSeparator(desktopId)
                                Layout.fillWidth: true
                                leftPadding: Kirigami.Units.gridUnit * 2
                                text: modelData
                                enabled: selectable
                                highlighted: root.memberSelected && treeRow !== null && root.selectedMemberStackId === treeRow.modelData.id
                                    && root.selectedMemberId === desktopId
                                onClicked: root.selectMember(treeRow.index, desktopId)
                                Accessible.name: modelData
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        visible: itemTree.count === 0
                        text: i18n("Add a stack or an application launcher.")
                    }
                }
            }

            RowLayout {
                enabled: !root.decoded.error
                PlasmaComponents.Button {
                    id: addButton
                    text: i18n("Add")
                    icon.name: "list-add"
                    enabled: root.decoded.items.length < 500
                    onClicked: addMenu.popup(addButton)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "go-up"
                    Accessible.name: i18n("Move up")
                    enabled: !root.memberSelected && root.selectedIndex > 0
                    onClicked: root.moveSelected(-1)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "go-down"
                    Accessible.name: i18n("Move down")
                    enabled: !root.memberSelected && root.selectedIndex >= 0 && root.selectedIndex < root.decoded.items.length - 1
                    onClicked: root.moveSelected(1)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "list-remove"
                    Accessible.name: i18n("Remove selected item")
                    enabled: !root.memberSelected && root.selectedIndex >= 0 && root.selectedIndex < root.decoded.items.length
                    onClicked: {
                        const index = root.selectedIndex
                        root.cfg_items = GroupItems.encode(GroupItems.remove(root.decoded.items, index))
                        root.selectedIndex = Math.min(index, root.decoded.items.length - 1)
                    }
                }
            }

            // The sidebar is narrow, so the three profile buttons stack
            // full-width instead of sharing a row; the message wraps.
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                PlasmaComponents.Button {
                    Layout.fillWidth: true
                    text: i18n("Import…")
                    onClicked: importDialog.open()
                }
                PlasmaComponents.Button {
                    id: exportButton
                    Layout.fillWidth: true
                    text: i18n("Export…")
                    enabled: !root.decoded.error
                    onClicked: exportMenu.popup(exportButton)
                    PlasmaComponents.Menu {
                        id: exportMenu
                        PlasmaComponents.MenuItem {
                            text: i18n("Entire group…")
                            onTriggered: { exportDialog.wholeGroup = true; exportDialog.open() }
                        }
                        PlasmaComponents.MenuItem {
                            text: i18n("Selected stack…")
                            enabled: root.selectedStack !== null
                            onTriggered: {
                                exportDialog.wholeGroup = false
                                exportDialog.exportSettings = root.selectedStack.settings
                                exportDialog.open()
                            }
                        }
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    visible: root.profileMessage.length > 0
                    text: root.profileMessage
                }
            }
        }

        // Inspector: breadcrumb and the selected item's page.
        ColumnLayout {
            id: inspector
            spacing: Kirigami.Units.largeSpacing
            QQC2.SplitView.fillWidth: true

            PlasmaComponents.Label {
                objectName: "breadcrumb"
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                textFormat: Text.StyledText
                elide: Text.ElideRight
                // cfg_groupNameDefault is "", so both branches fall back to the
                // tree header's "Group" label — the link is never empty. Both
                // the group name and the selected item's name are escaped.
                text: {
                    const groupName = root.escapeHtml(root.cfg_groupName || i18n("Group"))
                    return root.selectedIndex >= 0 && root.selectedItem
                        ? "<a href='group'>" + groupName + "</a>  ›  " + (root.memberSelected
                            ? "<a href='stack'>" + root.escapeHtml(root.selectedItemName) + "</a>  ›  " + root.escapeHtml(root.nameFor(root.selectedMemberId))
                            : root.escapeHtml(root.selectedItemName))
                        : groupName
                }
                onLinkActivated: link => { root.selectedMemberId = ""; if (link !== "stack") root.selectedIndex = -1 }
            }

            // Group page / launcher page / stack page. The stack page embeds
            // the shared StackSettingsEditor; the other two stay host-owned.
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                currentIndex: root.memberSelected ? 3 : root.selectedIndex < 0 ? 0
                    : root.selectedItem && ["application", "command"].includes(root.selectedItem.type) ? 1
                    : root.selectedItem && root.selectedItem.type === "stack" ? 2 : 0

                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 36
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    wideMode: false
                    PlasmaComponents.TextField {
                        id: groupNameField
                        Kirigami.FormData.label: i18n("Group name:")
                        placeholderText: i18n("TLBStacks Group")
                        maximumLength: 256
                    }
                    PanelIconSizeEditor {
                        objectName: "groupPanelSize"
                        spinObjectName: "groupIconSize"
                        Kirigami.FormData.label: i18n("Panel icon size:")
                        automaticLabel: i18n("Compact automatic")
                        value: root.cfg_panelIconSize
                        onEdited: size => root.cfg_panelIconSize = size
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: i18n("Default for all panel buttons. Each item can override it. Custom sizes are limited by panel space; popup icons are configured separately.")
                    }
                }
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 36
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    wideMode: false
                    PlasmaComponents.ComboBox {
                        visible: root.selectedItem && root.selectedItem.type === "application"
                        Kirigami.FormData.label: i18n("Application:")
                        Layout.fillWidth: true
                        Accessible.name: i18n("Launcher application")
                        textRole: "name"
                        model: root.catalog
                        currentIndex: root.selectedItem && root.selectedItem.type === "application"
                            ? root.catalog.findIndex(app => app.desktopId === root.selectedItem.desktopId) : -1
                        onActivated: root.replaceLauncherApp(root.catalog[currentIndex].desktopId)
                    }
                    PlasmaComponents.Button {
                        text: i18n("Edit custom launcher…")
                        visible: root.selectedItem && root.selectedItem.type === "command"
                        onClicked: panelCommandDialog.edit(root.selectedItem.id, root.selectedItem.command)
                    }
                    PlasmaComponents.TextField {
                        objectName: "launcherLabelField"
                        Kirigami.FormData.label: i18n("Label:")
                        Layout.fillWidth: true
                        maximumLength: 256
                        text: root.selectedItem && ["application", "command"].includes(root.selectedItem.type) ? root.selectedItem.label || "" : ""
                        placeholderText: root.selectedItem ? (root.selectedItem.type === "command" ? root.selectedItem.command.name : root.nameFor(root.selectedItem.desktopId)) : ""
                        onTextEdited: if (root.selectedItem) root.updateLauncherAppearance(root.selectedItem.id, {label: text})
                    }
                    RowLayout {
                        Kirigami.FormData.label: i18n("Icon:")
                        ApplicationIcon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: root.selectedItem && ["application", "command"].includes(root.selectedItem.type) ? root.launcherIcon(root.selectedItem) : ""
                            fallbackSource: root.selectedItem && root.selectedItem.type === "application" ? launcher.icon(root.selectedItem.desktopId) : ""
                            sourceAvailable: launcher.themeIconAvailable(source)
                        }
                        PlasmaComponents.Button { text: i18n("Choose…"); onClicked: root.chooseLauncherIcon(false) }
                        PlasmaComponents.Button { text: i18n("Image…"); onClicked: root.chooseLauncherIcon(true) }
                    }
                    PanelIconSizeEditor {
                        Kirigami.FormData.label: i18n("Panel icon size:")
                        value: root.selectedItem ? root.selectedItem.panelIconSize || 0 : 0
                        onEdited: size => { if (root.selectedItem) root.updateLauncherAppearance(root.selectedItem.id, {panelIconSize: size}) }
                    }
                    PlasmaComponents.Button {
                        text: i18n("Reset appearance")
                        enabled: root.selectedItem && !!(root.selectedItem.label || root.selectedItem.icon || root.selectedItem.panelIconSize)
                        onClicked: root.updateLauncherAppearance(root.selectedItem.id, {label: "", icon: "", panelIconSize: 0})
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: i18n("Opens this application directly from the panel.")
                    }
                }
                ColumnLayout {
                    PlasmaComponents.Label { text: i18n("Panel icon size:") }
                    PanelIconSizeEditor {
                        spinObjectName: "stackPanelIconSize"
                        value: root.selectedStack ? root.selectedStack.panelIconSize || 0 : 0
                        onEdited: size => { if (root.selectedStack) root.updateLauncherAppearance(root.selectedStack.id, {panelIconSize: size}) }
                    }
                StackSettingsEditor {
                    id: stackEditor
                    settings: root.selectedStack ? root.selectedStack.settings : {}
                    catalog: root.catalog
                    launcher: launcher
                    stackIconDefault: "applications-all"
                    onSettingsEdited: changes => root.updateStack(changes)
                }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: Kirigami.Units.largeSpacing
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.memberSelected ? root.nameFor(root.selectedMemberId) : ""
                        textFormat: Text.PlainText
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        ApplicationIcon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: root.memberSelected ? IconOverrides.get(root.selectedStack.settings.applicationIcons || {}, root.selectedMemberId)
                                || launcher.icon(root.selectedMemberId) || "application-x-executable" : ""
                            fallbackSource: root.memberSelected ? launcher.icon(root.selectedMemberId) || "application-x-executable" : ""
                            sourceAvailable: launcher.themeIconAvailable(source)
                        }
                        PlasmaComponents.Button { text: i18n("Choose icon…"); onClicked: root.chooseMemberIcon(false) }
                        PlasmaComponents.Button { text: i18n("Image…"); onClicked: root.chooseMemberIcon(true) }
                        PlasmaComponents.Button {
                            text: i18n("Reset")
                            enabled: root.memberSelected && !!IconOverrides.get(root.selectedStack.settings.applicationIcons || {}, root.selectedMemberId)
                            onClicked: root.applyMemberIcon(root.selectedStack.id, root.selectedMemberId, "")
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: i18n("This icon applies only to this application in this stack.")
                    }
                    PlasmaComponents.Button {
                        text: i18n("Back to stack contents")
                        onClicked: root.selectedMemberId = ""
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}

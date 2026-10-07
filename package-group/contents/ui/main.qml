pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import com.mattphilmon.tlbstacks
import "GroupItems.js" as GroupItems

PlasmoidItem {
    id: root
    readonly property var menuLauncher: launcher
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool onPanel: vertical || Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property string displayName: Plasmoid.configuration.groupName || i18n("TLBStacks Group")
    readonly property var decoded: GroupItems.decode(Plasmoid.configuration.items)
    property int catalogRevision: 0
    property var catalog: []
    property var folderHeights: ({})
    Component.onCompleted: catalog = launcher.applications()
    readonly property string folderHeightKey: activeStack ? JSON.stringify([activeStack.id,
        activeStack.settings.folderUrl, activeStack.settings.folderFilters, activeStack.settings.menuIconSize]) : ""
    property string launchError: ""
    property string activeStackId: ""
    property var activeButton: null
    readonly property var activeStack: decoded.items.find(item => item.id === activeStackId && item.type === "stack") || null
    readonly property var stackEntries: {
        const revision = catalogRevision
        if (!activeStack) return []
        const cfg = activeStack.settings
        if (cfg.menuSource === "folder") return []
        if (cfg.menuSource === "activity") return activeButton ? activeButton.activityEntries : []
        const ids = cfg.menuSource === "categories"
            ? ApplicationCategories.matching(catalog, cfg.applicationCategories).map(app => app.desktopId)
            : cfg.applications
        return launcher.applicationEntries(ids, {}, cfg.menuSource).filter(entry => entry.available)
    }
    readonly property string stackNotice: {
        if (!activeStack) return ""
        const cfg = activeStack.settings
        if (cfg.menuSource === "activity") return activeButton && activeButton.activityLoading
            ? i18n("Loading usage history…") : activeButton ? activeButton.activityMessage : ""
        if (cfg.menuSource === "categories") return cfg.applicationCategories.length
            ? i18n("No matching applications.") : i18n("Choose categories in configuration.")
        return i18n("Add applications in group configuration.")
    }

    onDecodedChanged: {
        if (stackPopup) stackPopup.visible = false
    }
    function showStack(button, toggle) {
        if (toggle && stackPopup.visible && activeStackId === button.modelData.id) {
            stackPopup.visible = false
            return
        }
        if (stackPopup.visible && activeStackId === button.modelData.id) return
        stackPopup.visible = false
        launcher.closeApplicationContextMenu()
        launcher.invalidateActivations()
        launchError = ""
        activeButton = button
        activeStackId = button.modelData.id
        stackPopup.visible = true
        activityRefresh.restart()
        Qt.callLater(() => { if (stackPopup.visible) stackMenu.resetSelection() })
    }
    Timer {
        id: activityRefresh
        interval: 50
        onTriggered: {
            if (stackPopup.visible && root.activeButton) root.activeButton.refreshActivity()
        }
    }
    PlasmaCore.Dialog {
        id: stackPopup
        visualParent: root.activeButton
        location: Plasmoid.location
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.Popup | Qt.FramelessWindowHint
        hideOnWindowDeactivate: true
        onVisibleChanged: {
            if (!visible) {
                activityRefresh.stop()
                launcher.closeApplicationContextMenu()
                if (root.activeButton) root.activeButton.forceActiveFocus()
                root.activeStackId = ""
            }
        }
        mainItem: GroupStackContent {
            id: stackMenu
            launcher: root.menuLauncher
            entries: root.stackEntries
            iconsOnly: root.activeStack ? root.activeStack.settings.iconsOnly : false
            iconSize: root.activeStack ? root.activeStack.settings.menuIconSize : 22
            popupOpen: stackPopup.visible
            errorText: root.launchError
            menuSource: root.activeStack ? root.activeStack.settings.menuSource : "applications"
            folderUrl: root.activeStack ? root.activeStack.settings.folderUrl : ""
            folderFilters: root.activeStack ? root.activeStack.settings.folderFilters : "*"
            hoverDelay: root.activeStack ? root.activeStack.settings.hoverDelay : 250
            emptyText: root.stackNotice
            initialFolderHeight: root.folderHeights[root.folderHeightKey] || Math.max(40, iconSize + 16) * 2
            onFolderHeightReady: height => {
                root.folderHeights = Object.assign({}, root.folderHeights, {[root.folderHeightKey]: height})
            }
            onDismissRequested: stackPopup.visible = false
            onActivating: root.launchError = ""
            onActivated: stackPopup.visible = false
        }
    }

    Plasmoid.icon: "view-grid"
    toolTipMainText: displayName
    toolTipSubText: launchError || (decoded.error ? i18n("Unsupported group settings. Open configuration for details.")
        : decoded.items.length ? i18n("Stacks and launchers") : i18n("Empty group — click to configure"))
    preferredRepresentation: fullRepresentation

    Launcher {
        id: launcher
        onApplicationsChanged: { root.catalogRevision++; root.catalog = launcher.applications() }
        onActivationFailed: message => { root.launchError = message }
        onRemoveApplicationRequested: desktopId => {
            if (!root.activeStack || root.activeStack.settings.menuSource !== "applications") return
            const items = GroupItems.updateStack(root.decoded.items, root.activeStackId, {
                applications: root.activeStack.settings.applications.filter(id => id !== desktopId)
            })
            Plasmoid.configuration.items = GroupItems.encode(items)
        }
    }
    function configure() {
        const action = Plasmoid.internalAction("configure")
        if (action) action.trigger()
    }
    fullRepresentation: Item {
        id: content
        readonly property real cellSize: root.onPanel
            ? Math.max(Kirigami.Units.gridUnit * 2, Math.min(128, root.vertical ? root.width : root.height))
            : Kirigami.Units.gridUnit * 2
        readonly property int count: Math.max(1, root.decoded.items.length)
        implicitWidth: root.vertical ? cellSize : count * cellSize
        implicitHeight: root.vertical ? count * cellSize : cellSize
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        function focusEntry(index) {
            if (buttons.count) buttons.itemAt((index + buttons.count) % buttons.count).forceActiveFocus()
        }
        GridLayout {
            anchors.fill: parent
            columns: root.vertical ? 1 : content.count
            rowSpacing: 0
            columnSpacing: 0
            PlasmaComponents.ToolButton {
                visible: root.decoded.items.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon.name: root.decoded.error ? "dialog-warning" : "view-grid"
                Accessible.name: i18n("Configure %1", root.displayName)
                onClicked: root.configure()
            }
            Repeater {
                id: buttons
                model: root.decoded.items
                PlasmaComponents.ToolButton {
                    id: button
                    required property var modelData
                    required property int index
                    readonly property bool activityStack: modelData.type === "stack" && modelData.settings.menuSource === "activity"
                    readonly property var activityEntries: activityLoader.item ? activityLoader.item.entries : []
                    readonly property bool activityLoading: activityLoader.item ? activityLoader.item.loading : false
                    readonly property string activityMessage: activityLoader.item ? activityLoader.item.message : ""
                    readonly property string activityKey: activityStack ? JSON.stringify(modelData.settings) : ""
                    onActivityKeyChanged: refreshActivity()
                    function refreshActivity() {
                        if (!activityStack || !activityLoader.item) return
                        const cfg = modelData.settings
                        activityLoader.item.refresh(cfg.activityOrder === "frequent", cfg.activityLimit,
                            cfg.applicationCategories, cfg.activityCurrent)
                    }
                    Loader {
                        id: activityLoader
                        active: button.activityStack
                        sourceComponent: ActivitySource {}
                        onLoaded: button.refreshActivity()
                    }
                    readonly property string appName: {
                        const revision = root.catalogRevision
                        return modelData.type === "stack" ? modelData.settings.groupName || i18n("Stack")
                            : launcher.name(modelData.desktopId) || modelData.desktopId
                    }
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: content.cellSize
                    Layout.preferredHeight: content.cellSize
                    activeFocusOnTab: true
                    display: QQC2.AbstractButton.IconOnly
                    text: appName
                    icon.name: {
                        const revision = root.catalogRevision
                        return modelData.type === "stack" ? modelData.settings.groupIcon || "applications-all"
                            : launcher.icon(modelData.desktopId) || "application-x-executable"
                    }
                    icon.color: "transparent"
                    Accessible.name: appName
                    onClicked: {
                        root.launchError = ""
                        if (modelData.type === "stack") root.showStack(button, true)
                        else { stackPopup.visible = false; launcher.launch(modelData.desktopId) }
                    }
                    hoverEnabled: true
                    onHoveredChanged: {
                        if (hovered && modelData.type === "stack") hoverOpen.restart()
                        else hoverOpen.stop()
                    }
                    Timer {
                        id: hoverOpen
                        interval: button.modelData.type === "stack" ? button.modelData.settings.hoverDelay : 250
                        onTriggered: if (button.hovered) root.showStack(button, false)
                    }
                    Keys.onLeftPressed: content.focusEntry(index - 1)
                    Keys.onRightPressed: content.focusEntry(index + 1)
                    Keys.onUpPressed: content.focusEntry(index - 1)
                    Keys.onDownPressed: content.focusEntry(index + 1)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
                            content.focusEntry(event.key === Qt.Key_Home ? 0 : buttons.count - 1)
                            event.accepted = true
                        }
                    }
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    PlasmaComponents.ToolTip {
                        text: root.launchError || button.appName
                        delay: 700
                    }
                }
            }
        }
    }
}

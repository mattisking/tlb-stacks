import QtQuick
import "MenuNavigation.js" as Navigation
import QtQuick.Window
import QtQuick.Controls as QQC2
import "IconOverrides.js" as IconOverrides
import "ApplicationCategories.js" as Categories
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import com.mattphilmon.tlbstacks

PlasmoidItem {
    id: root

    Plasmoid.icon: Plasmoid.configuration.groupIcon || "applications-all"

    toolTipMainText: Plasmoid.configuration.groupName || "TLBStacks"
    toolTipSubText: "TLBStacks"

    Launcher {
        id: launcher
        onApplicationsChanged: {
            root.catalogRevision++
            root.refreshCategoryApplications()
        }
        onActivationFailed: message => { root.activationError = message }
        onRemoveApplicationRequested: desktopId => {
            if (root.menuSource !== "applications") return
            const remaining = Array.from(Plasmoid.configuration.applications || [])
                .filter(id => id !== desktopId)
            Plasmoid.configuration.applications = remaining
            if (remaining.length === 0) root.expanded = false
        }
    }

    readonly property var applicationIcons: IconOverrides.parse(Plasmoid.configuration.applicationIcons)

    readonly property int hoverDelay: Math.max(0, Math.min(2000, Plasmoid.configuration.hoverDelay))

    readonly property bool iconsOnly: menuSource !== "folder" && Plasmoid.configuration.iconsOnly
    readonly property int menuIconSize: Math.max(16, Math.min(64,
        Plasmoid.configuration.menuIconSize || 22))
    readonly property int menuRowHeight: Math.max(40, menuIconSize + 16)
    readonly property int menuWidth: iconsOnly ? menuRowHeight : 220 + Math.max(0, menuIconSize - 22)

    property int catalogRevision: 0
    property string activationError: ""
    readonly property var entries: {
        const revision = catalogRevision
        return launcher.applicationEntries(root.applications, root.applicationIcons, root.menuSource)
    }
    readonly property var visibleEntries: entries.filter(entry => entry.available)
    property var categoryApplications: []
    readonly property var selectedCategories: Plasmoid.configuration.applicationCategories
    readonly property string menuSource: Plasmoid.configuration.menuSource
    property var applications: menuSource === "categories"
        ? Categories.matching(categoryApplications, selectedCategories).map(app => app.desktopId)
        : Plasmoid.configuration.applications
    readonly property string activationContextKey: JSON.stringify([menuSource, applications])
    onActivationContextKeyChanged: {
        if (launcher) launcher.invalidateActivations()
        root.activationError = ""
    }
    function refreshCategoryApplications() {
        if (menuSource === "categories") categoryApplications = launcher.applications()
    }
    onMenuSourceChanged: {
        launcher.invalidateActivations()
        root.activationError = ""
        launcher.closeApplicationContextMenu()
        refreshCategoryApplications()
    }
    Component.onCompleted: refreshCategoryApplications()

    // Attach to Plasma's existing panel button so its sizing, icon and
    // click/keyboard behavior stay managed by the shell.
    HoverHandler {
        id: panelHover
        parent: root.compactRepresentationItem
        onHoveredChanged: {
            if (hovered && !root.expanded) {
                if (root.hoverDelay === 0) root.expanded = true
                else hoverOpenTimer.restart()
            } else {
                hoverOpenTimer.stop()
            }
        }
    }

    Timer {
        id: hoverOpenTimer
        interval: root.hoverDelay
        onTriggered: {
            if (panelHover.hovered && !root.expanded) {
                root.expanded = true
            }
        }
    }

    onExpandedChanged: {
        hoverOpenTimer.stop()
        if (expanded) refreshCategoryApplications()
        else launcher.closeApplicationContextMenu()
    }

    fullRepresentation: ColumnLayout {
        id: launcherColumn

        spacing: 0
        property int selectedApplication: -1
        property int hoveredApplication: -1
        property bool keyboardNavigation: false

        function moveApplicationSelection(step) {
            if (root.menuSource === "folder") return
            const index = Navigation.nextIndex(applicationRepeater.count, selectedApplication,
                                               hoveredApplication, keyboardNavigation, step)
            if (index < 0) return
            selectedApplication = index
            keyboardNavigation = true
            const item = applicationRepeater.itemAt(index)
            if (!item) return
            item.forceActiveFocus(Qt.TabFocusReason)
            const viewport = applicationScroll.contentItem
            if (viewport && viewport.contentY !== undefined) {
                if (item.y < viewport.contentY) viewport.contentY = item.y
                else if (item.y + item.height > viewport.contentY + viewport.height)
                    viewport.contentY = item.y + item.height - viewport.height
            }
        }
        Keys.onUpPressed: event => {
            if (root.menuSource !== "folder") { moveApplicationSelection(-1); event.accepted = true }
        }
        Keys.onDownPressed: event => {
            if (root.menuSource !== "folder") { moveApplicationSelection(1); event.accepted = true }
        }
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded && root.menuSource !== "folder") {
                    launcherColumn.selectedApplication = -1
                    launcherColumn.hoveredApplication = -1
                    launcherColumn.keyboardNavigation = false
                    Qt.callLater(function() {
                        if (root.expanded && root.menuSource !== "folder") launcherColumn.forceActiveFocus()
                    })
                }
            }
        }

        Layout.minimumWidth: root.menuWidth
        Layout.preferredWidth: root.menuWidth
        Layout.maximumWidth: root.menuWidth

        implicitWidth: root.menuWidth
        // Layouts calculate their own implicit size. Keep the folder's requested
        // height separate so loading results can grow a previously short popup.
        readonly property string folderHeightKey: JSON.stringify([
            Plasmoid.configuration.folderUrl, Plasmoid.configuration.folderFilters,
            root.menuRowHeight])
        readonly property real rememberedFolderHeight: {
            try {
                const cache = JSON.parse(Plasmoid.configuration.folderHeightCache || "{}")
                if (cache.key === folderHeightKey && Number.isFinite(cache.height))
                    return Math.max(root.menuRowHeight, Math.min(480, cache.height))
            } catch (error) {}
            return root.menuRowHeight * 2
        }
        readonly property real folderMenuHeight: folderLoader.item
            ? folderLoader.item.preferredMenuHeight : rememberedFolderHeight
        implicitHeight: folderLoader.active ? folderMenuHeight : childrenRect.height
        Layout.minimumHeight: folderLoader.active ? folderMenuHeight : 0
        Layout.preferredHeight: folderLoader.active ? folderMenuHeight : implicitHeight

        // Plasma can retain the saved window size while the async list grows.
        // Resize the applet popup itself; layout hints alone only resize its items.
        function syncFolderPopupHeight() {
            const popup = launcherColumn.Window.window
            if (!root.expanded || !folderLoader.active || !popup
                    || !popup.mainItem || popup.appletInterface !== root) return
            const extra = popup.mainItem.extraHeight || 0
            const wanted = Math.ceil(folderMenuHeight + extra
                + popup.topPadding + popup.bottomPadding)
            if (wanted > 0 && popup.height !== wanted) popup.height = wanted
        }
        onFolderMenuHeightChanged: Qt.callLater(syncFolderPopupHeight)
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) Qt.callLater(launcherColumn.syncFolderPopupHeight)
            }
        }
        Connections {
            target: launcherColumn.Window.window
            function onVisibleChanged() {
                Qt.callLater(launcherColumn.syncFolderPopupHeight)
            }
        }

        Loader {
            id: folderLoader
            active: Plasmoid.configuration.menuSource === "folder"
            visible: active
            Layout.fillWidth: true
            Layout.preferredHeight: launcherColumn.folderMenuHeight
            sourceComponent: FolderMenu {
                initialMenuHeight: launcherColumn.rememberedFolderHeight
                onListingHeightReady: height => {
                    const cache = JSON.stringify({key: launcherColumn.folderHeightKey, height: height})
                    if (Plasmoid.configuration.folderHeightCache !== cache)
                        Plasmoid.configuration.folderHeightCache = cache
                }
                folderUrl: Plasmoid.configuration.folderUrl
                filters: Plasmoid.configuration.folderFilters
                iconsOnly: root.iconsOnly
                iconSize: root.menuIconSize
                rowHeight: root.menuRowHeight
                menuWidth: root.menuWidth
                onDismissRequested: root.expanded = false
                popupOpen: root.expanded
                onLoadingChanged: Qt.callLater(launcherColumn.syncFolderPopupHeight)
                hoverDelay: root.hoverDelay
            }
        }

        PlasmaComponents.Label {
            visible: root.menuSource === "categories" && root.applications.length === 0
            Layout.fillWidth: true
            Layout.maximumWidth: root.menuWidth
            wrapMode: Text.WordWrap
            text: root.selectedCategories.length === 0
                ? i18n("Choose categories in configuration.") : i18n("No matching applications.")
        }
        PlasmaComponents.Label {
            visible: root.menuSource === "applications" && root.visibleEntries.length === 0
            Layout.fillWidth: true
            Layout.maximumWidth: root.menuWidth
            text: root.applications.length ? i18n("Saved applications are unavailable. Open configuration to review them.")
                                          : i18n("Add applications in configuration.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        PlasmaComponents.Label {
            visible: root.activationError.length > 0 && root.menuSource !== "folder"
            Layout.fillWidth: true
            text: root.activationError
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        PlasmaComponents.ScrollView {
            id: applicationScroll
            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            visible: root.menuSource !== "folder" && root.visibleEntries.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.visibleEntries.length * root.menuRowHeight, 480)
            ColumnLayout {
                width: applicationScroll.availableWidth
                spacing: 0
                Repeater {
                    id: applicationRepeater
                    model: root.visibleEntries
                    onCountChanged: launcherColumn.selectedApplication = -1

                    delegate: PlasmaComponents.ItemDelegate {
                        id: launcherItem

                        required property int index
                        required property var modelData

                        readonly property string applicationName:
                            modelData.name

                        readonly property string applicationIcon:
                            modelData.icon

                        visible: modelData.available

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: applicationScroll.availableWidth

                        implicitHeight: root.menuRowHeight
                        Layout.minimumHeight: root.menuRowHeight
                        Layout.preferredHeight: root.menuRowHeight
                        Layout.maximumHeight: root.menuRowHeight

                        text: applicationName
                        icon.name: IconOverrides.isFile(applicationIcon) ? "" : applicationIcon
                        icon.source: IconOverrides.isFile(applicationIcon) ? applicationIcon : ""
                        icon.width: root.menuIconSize
                        icon.height: root.menuIconSize
                        display: root.iconsOnly ? QQC2.AbstractButton.IconOnly
                                                : QQC2.AbstractButton.TextBesideIcon
                        contentItem: RowLayout {
                            spacing: launcherItem.spacing
                            ApplicationIcon {
                                source: launcherItem.applicationIcon
                                Layout.preferredWidth: root.menuIconSize
                                Layout.preferredHeight: root.menuIconSize
                                Layout.alignment: Qt.AlignCenter
                                Layout.fillWidth: root.iconsOnly
                            }
                            PlasmaComponents.Label {
                                visible: !root.iconsOnly
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: launcherItem.applicationName
                                elide: Text.ElideRight
                            }
                        }
                        Keys.onUpPressed: launcherColumn.moveApplicationSelection(-1)
                        Keys.onDownPressed: launcherColumn.moveApplicationSelection(1)
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        highlighted: launcherColumn.keyboardNavigation && launcherColumn.selectedApplication === index
                        onHoveredChanged: {
                            if (hovered) {
                                launcherColumn.hoveredApplication = index
                                launcherColumn.keyboardNavigation = false
                            } else if (launcherColumn.hoveredApplication === index) launcherColumn.hoveredApplication = -1
                        }
                        hoverEnabled: true
                        Accessible.name: applicationName || modelData.id

                        StackToolTip {
                            id: applicationToolTip
                            anchors.fill: parent
                            text: (launcherItem.applicationName || launcherItem.modelData.id)
                                + (launcherItem.modelData.description ? "\n" + launcherItem.modelData.description : "")
                            selected: root.expanded && launcherItem.visible
                                && (launcherColumn.keyboardNavigation
                                    ? launcherColumn.selectedApplication === launcherItem.index
                                    : launcherItem.hovered)
                        }

                        // Consume only right-clicks; normal activation stays with the delegate.
                        MouseArea {
                            anchors.fill: parent
                            enabled: launcherItem.modelData.actions.indexOf("removeFromStack") !== -1
                            acceptedButtons: Qt.RightButton
                            onClicked: {
                                applicationToolTip.hideToolTip()
                                launcher.showEntryContextMenu(launcherItem, launcherItem.modelData)
                            }
                        }
                        Keys.onMenuPressed: event => {
                            if (launcherItem.modelData.actions.indexOf("removeFromStack") !== -1) {
                                applicationToolTip.hideToolTip()
                                launcher.showEntryContextMenu(launcherItem, launcherItem.modelData)
                                event.accepted = true
                            }
                        }

                        onClicked: {
                            root.activationError = ""
                            if (launcher.activateEntry(modelData)) {
                                root.expanded = false
                            }
                        }
                    }
                }
            }
        }
    }
}
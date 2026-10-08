pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import "IconOverrides.js" as IconOverrides
import "ApplicationCategories.js" as Categories
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import com.mattphilmon.tlbstacks

PlasmoidItem {
    id: root
    readonly property var menuLauncher: launcher

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
            const commands = Object.assign({}, StackMembers.parseCustomLaunchers(Plasmoid.configuration.customLaunchers))
            delete commands[desktopId]
            Plasmoid.configuration.customLaunchers = JSON.stringify(commands)
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
    readonly property int separatorRowHeight: 10
    readonly property int labeledSeparatorRowHeight: 28
    function entryHeight(entry) {
        if (entry.isSeparator !== true) return menuRowHeight
        return !iconsOnly && entry.name ? labeledSeparatorRowHeight : separatorRowHeight
    }
    readonly property real applicationMenuHeight: visibleEntries.reduce(
        (height, entry) => height + entryHeight(entry), 0)
    readonly property int menuWidth: iconsOnly ? menuRowHeight : 220 + Math.max(0, menuIconSize - 22)

    ActivitySource { id: activitySource }
    function refreshActivity() {
        if (menuSource === "activity") activitySource.refresh(
            Plasmoid.configuration.activityOrder === "frequent",
            Plasmoid.configuration.activityLimit, selectedCategories,
            Plasmoid.configuration.activityCurrent)
    }
    property int catalogRevision: 0
    property string activationError: ""
    readonly property var entries: {
        const revision = catalogRevision
        if (root.menuSource === "activity") return activitySource.entries
        return launcher.applicationEntries(root.applications, root.applicationIcons, root.menuSource, StackMembers.parseCustomLaunchers(Plasmoid.configuration.customLaunchers))
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
        refreshActivity()
    }
    Component.onCompleted: { refreshCategoryApplications(); refreshActivity(); attachPanelHover() }

    // Attach to Plasma's existing panel button so its sizing, icon and
    // click/keyboard behavior stay managed by the shell.
    // A handler can't be reliably re-parented by binding, so create it on the
    // compact item once Plasma has instantiated it.
    property var panelHover: null
    readonly property bool panelHovered: panelHover ? panelHover.hovered : false
    function attachPanelHover() {
        const item = root.compactRepresentationItem
        if (!item || (panelHover && panelHover.parent === item)) return
        if (panelHover) panelHover.destroy()
        panelHover = panelHoverComponent.createObject(item)
    }
    onCompactRepresentationItemChanged: attachPanelHover()
    Component {
        id: panelHoverComponent
        HoverHandler {}
    }
    onPanelHoveredChanged: {
        if (panelHovered && !expanded) {
            if (hoverDelay === 0) expanded = true
            else hoverOpenTimer.restart()
        } else {
            hoverOpenTimer.stop()
        }
    }

    Timer {
        id: hoverOpenTimer
        interval: root.hoverDelay
        onTriggered: {
            if (root.panelHovered && !root.expanded) {
                root.expanded = true
            }
        }
    }

    onExpandedChanged: {
        hoverOpenTimer.stop()
        if (expanded) { refreshCategoryApplications(); refreshActivity() }
        else launcher.closeApplicationContextMenu()
    }

    fullRepresentation: ColumnLayout {
        id: launcherColumn

        spacing: 0
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
        readonly property real activityMenuHeight: root.visibleEntries.length > 0
            ? Math.min(applicationMenu.menuContentHeight, 480)
            : Math.max(root.menuRowHeight, activityNotice.implicitHeight)
        readonly property real dynamicMenuHeight: folderLoader.active ? folderMenuHeight : activityMenuHeight
        readonly property bool dynamicMenu: folderLoader.active || root.menuSource === "activity"
            || root.visibleEntries.length > 0
        implicitHeight: dynamicMenu ? dynamicMenuHeight : childrenRect.height
        Layout.minimumHeight: dynamicMenu ? dynamicMenuHeight : 0
        Layout.preferredHeight: dynamicMenu ? dynamicMenuHeight : implicitHeight

        // Plasma can retain the saved window size while the async list grows.
        // Resize the applet popup itself; layout hints alone only resize its items.
        function syncFolderPopupHeight() {
            const popup = launcherColumn.Window.window
            if (!root.expanded || !dynamicMenu || !popup
                    || !popup.mainItem || popup.appletInterface !== root) return
            const extra = popup.mainItem.extraHeight || 0
            const wanted = Math.ceil(dynamicMenuHeight + extra
                + popup.topPadding + popup.bottomPadding)
            if (wanted > 0 && popup.height !== wanted) popup.height = wanted
        }
        onDynamicMenuHeightChanged: Qt.callLater(syncFolderPopupHeight)
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
            id: activityNotice
            visible: root.menuSource === "activity" && root.visibleEntries.length === 0
            Layout.fillWidth: true
            Layout.maximumWidth: root.menuWidth
            wrapMode: Text.WordWrap
            text: activitySource.loading ? i18n("Loading usage history…") : activitySource.message
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
        ApplicationMenu {
            id: applicationMenu
            launcher: root.menuLauncher
            entries: root.visibleEntries
            iconsOnly: root.iconsOnly
            iconSize: root.menuIconSize
            popupOpen: root.expanded && root.menuSource !== "folder"
            visible: root.menuSource !== "folder" && root.visibleEntries.length > 0
            onActivating: root.activationError = ""
            onActivated: root.expanded = false
        }

    }
}
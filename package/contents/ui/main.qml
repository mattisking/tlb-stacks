pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import "IconOverrides.js" as IconOverrides
import "ApplicationCategories.js" as Categories
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import com.mattphilmon.tlbstacks

PlasmoidItem {
    id: root
    readonly property var menuLauncher: launcher
    // Live window bridge (null when its module is unavailable); the shared
    // menu delegates and the panel indicator degrade without it.
    readonly property var taskArea: taskLoader.status === Loader.Ready ? taskLoader.item : null

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
        onCloseWindowRequested: desktopId => {
            // Polite window close through the live task bridge; a degraded
            // widget (no taskArea) ignores the request.
            if (!root.taskArea) return
            root.taskArea.close(desktopId)
        }
    }

    // TaskArea brings the live window database for the shared menu delegates
    // and the panel indicator (always on — the standalone has no task-tracking
    // config, per spec); loading it by URL degrades to launcher-only mode
    // wherever its module is unavailable. Deliberately not an inline Component:
    // TaskArea.qml is the one file that imports org.kde.taskmanager, and an
    // inline component is compiled together with this root, so that module would
    // have to resolve for the whole widget to load at all (the TaskThumbnail
    // pattern).
    Loader {
        id: taskLoader
        source: "TaskArea.qml"
        // A URL-loaded item cannot be given properties at creation, so the
        // widget's claimed desktop ids are bound once it exists.
        onLoaded: if (item) item.desktopIds = Qt.binding(() => root.desktopIds)
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
    // Desktop IDs this widget claims: its applications list (already the
    // category matches in categories mode) plus materialized activity
    // entries. Custom launcher commands and separators are never collected —
    // commands stay launch-only, so their windows surface as unclaimed tasks
    // in groups instead.
    readonly property var desktopIds: {
        const commands = StackMembers.parseCustomLaunchers(Plasmoid.configuration.customLaunchers)
        const ids = (applications || []).filter(id => id && !commands[id] && !StackMembers.isSeparator(id))
        if (menuSource === "activity")
            for (const entry of activitySource.entries)
                if (entry.id && entry.isSeparator !== true) ids.push(entry.id)
        return ids
    }
    // True when any member app is running; touching taskArea.revision keeps
    // it fresh, like the group's stack-button indicator.
    readonly property bool memberRunning: {
        if (!taskArea) return false
        taskArea.revision
        for (const id of desktopIds) if (taskArea.stateFor(id).running) return true
        return false
    }
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
    Component.onCompleted: { refreshCategoryApplications(); refreshActivity(); attachPanelHover(); attachRunningDot() }

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
    onCompactRepresentationItemChanged: { attachPanelHover(); attachRunningDot() }
    Component {
        id: panelHoverComponent
        HoverHandler {}
    }
    // The panel button's running-member dot, attached to Plasma's compact
    // item like the hover handler above: dimmed while any member app runs,
    // like the group's stack buttons.
    property var runningDot: null
    function attachRunningDot() {
        const item = root.compactRepresentationItem
        if (!item || (runningDot && runningDot.parent === item)) return
        if (runningDot) runningDot.destroy()
        runningDot = runningDotComponent.createObject(item)
    }
    Component {
        id: runningDotComponent
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(1, Math.round(parent.height / 24))
            width: Math.max(3, Math.round(parent.height / 10))
            height: width
            radius: width / 2
            visible: root.memberRunning
            color: Kirigami.Theme.highlightColor
            opacity: 0.7
        }
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
            taskArea: root.taskArea
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
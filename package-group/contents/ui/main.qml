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
import "ClickMatrix.js" as ClickMatrix

PlasmoidItem {
    id: root
    readonly property var menuLauncher: launcher
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool onPanel: vertical || Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property string displayName: Plasmoid.configuration.groupName || i18n("TLBStacks Group")
    readonly property var decoded: GroupItems.decode(Plasmoid.configuration.items)
    readonly property var taskArea: taskLoader.status === Loader.Ready ? taskLoader.item : null
    // Configured items plus live task buttons for windows no group item claims.
    // Every task revision re-evaluates the concat into a fresh array; writing
    // that straight to the Repeater would rebuild every panel button on each
    // system-wide window event, dangle the open popup's anchor button, and
    // re-run every activity query. The handler below hands the buttons the
    // same array unless the content actually changed.
    readonly property var panelItemsSource: decoded.items.concat(taskArea ? taskArea.unclaimed : [])
    property var panelItems: []
    onPanelItemsSourceChanged: {
        if (ClickMatrix.samePanelItems(panelItems, panelItemsSource)) return
        panelItems = panelItemsSource
    }
    onPanelItemsChanged: {
        // A real content change rebuilds every panel button, so an open
        // popup's anchor is about to be destroyed — close it like a decoded
        // change does and drop the reference before the rebuild lands.
        if (stackPopup) stackPopup.visible = false
        activeButton = null
    }
    property var activityIds: ({})  // activity stack id → materialized desktop ids
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
        return launcher.applicationEntries(ids, cfg.applicationIcons || {}, cfg.menuSource, cfg.customLaunchers || {}).filter(entry => entry.available)
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

    // Desktop IDs the group claims, per the ownership rule: panel-direct
    // applications plus every stack's members — stack member lists, category
    // matches, and materialized activity entries. Custom launchers are never
    // collected: command items stay launch-only, so their windows auto-append.
    // The catalog/activityIds reads below are otherwise invisible to this
    // binding (stackDesktopIds hides them); touching them keeps it fresh.
    readonly property var desktopIds: {
        catalog
        activityIds
        const seen = new Set()
        const ids = []
        const add = id => { if (id && !seen.has(id)) { seen.add(id); ids.push(id) } }
        for (const item of decoded.items) {
            if (item.type === "application") add(item.desktopId)
            else if (item.type === "stack") for (const id of stackDesktopIds(item)) add(id)
        }
        return ids
    }
    function stackDesktopIds(item) {
        const cfg = item.settings
        const commands = cfg.customLaunchers || {}
        const ids = []
        for (const id of cfg.applications || [])
            if (!commands[id] && !StackMembers.isSeparator(id)) ids.push(id)
        if (cfg.menuSource === "categories")
            for (const app of ApplicationCategories.matching(catalog, cfg.applicationCategories)) ids.push(app.desktopId)
        if (cfg.menuSource === "activity")
            for (const id of activityIds[item.id] || []) ids.push(id)
        return ids
    }
    // Activity stacks claim ids only once their entries have materialized; the
    // collected ids persist across button rebuilds so the claim set never
    // flickers empty while an activity query reloads.
    function rememberActivityIds(stackId, ids) {
        activityIds = Object.assign({}, activityIds, {[stackId]: ids})
    }
    // The left-click matrix: an idle app launches, a running one activates
    // its most recent window, the focused one minimizes — except a focused
    // group of windows, which cycles to its next member. Appended task
    // buttons have no launch fallback.
    function clickTask(item) {
        const decision = ClickMatrix.decideClick(item.desktopId, taskArea)
        const launch = () => {
            if (item.type === "application") launcher.launch(item.desktopId, item.arguments || [])
        }
        if (decision === "launch") {
            launch()
            return
        }
        const area = taskArea
        if (decision === "minimize" && area.stateFor(item.desktopId).count > 1) {
            if (!area.cycle(item.desktopId)) launch()
            return
        }
        if (!area.activate(item.desktopId)) launch()
    }
    // Middle-click: a new window when the app is running, otherwise launch.
    function newTaskInstance(item) {
        if (taskArea && taskArea.newInstance(item.desktopId)) return
        if (item.type === "application") launcher.launch(item.desktopId, item.arguments || [])
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
        // A switch (another popup already open) closes and instantly reopens
        // this same Dialog window. The close queues a deactivation that is
        // delivered after the reopen; the grace window in the popup's
        // onActiveChanged keeps that stale event from killing the new popup.
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
    // Companion to the popup's deactivation grace: a grace-ignored (stale
    // switch) deactivation leaves the popup visible but inactive, which would
    // make it unclosable by focus changes. Once the focus war settles, either
    // re-assert activation (owner still hovered) or close (owner abandoned).
    Timer {
        id: reactivateTimer
        interval: 350
        onTriggered: {
            if (!stackPopup.visible) return
            if (stackPopup.active) return
            if (root.activeButton && root.activeButton.hovered) {
                stackPopup.requestActivate()
            } else {
                stackPopup.visible = false
            }
        }
    }
    // Watchdog: whatever way a popup ends up visible but inactive (stale
    // switch event, denied re-assert), it will receive no further focus
    // events and could linger over the desktop forever. Reap it when it is
    // inactive and the mouse is neither on its owner button nor inside the
    // menu. Active popups are never touched; the settling age avoids racing
    // the grace window and KWin's focus transitions after a switch.
    Timer {
        id: popupWatchdog
        interval: 400
        repeat: true
        running: stackPopup.visible
        onTriggered: {
            if (stackPopup.active) return
            if (root.activeButton && root.activeButton.hovered) return
            if (stackMenu.menuHovered) return
            if (Date.now() - stackPopup.openedAt < 500) return
            stackPopup.visible = false
        }
    }
    PlasmaCore.Dialog {
        id: stackPopup
        visualParent: root.activeButton
        location: Plasmoid.location
        // Match Plasma's own panel popups (systemtray, kicker submenus):
        // AppletPopup type, no Qt.Popup flags, hideOnWindowDeactivate, and
        // keyboard focus taken on show. Qt.Popup must stay off: on Wayland it
        // turns the dialog into a grabbed xdg_popup, whose compositor grab
        // never dismisses for presses on plasmashell's own surfaces (panel
        // and desktop are the same Wayland client), so no outside click
        // could close it — only Esc, which KWin forwards to grabbed popups.
        type: PlasmaCore.Dialog.AppletPopup
        // Manual, not declarative: this Dialog is a single window reused
        // across stack switches, and the close half of a switch queues a
        // deactivation that is delivered AFTER the reopen — hideOnWindowDeactivate
        // would honor that stale event and kill the new popup. Deactivations
        // inside the post-open grace window are switch artifacts; later ones
        // are genuine focus changes (outside click / another window) and close.
        hideOnWindowDeactivate: false
        property double openedAt: 0
        // Deactivation handling lives in onActiveChanged: Plasma only emits
        // windowDeactivated while hideOnWindowDeactivate is true (which would
        // also auto-hide on the stale switch event), so the window's own
        // active property is the reliable detector.
        onActiveChanged: {
            if (active) return
            const age = Date.now() - openedAt
            if (age < 300) {
                // The stale event leaves the popup visible but inactive — and
                // an inactive popup gets no further focus events, so click-away
                // could never close it. Re-assert (or close) once settled.
                reactivateTimer.restart()
                return
            }
            if (root.activeButton && root.activeButton.hovered) {
                requestActivate()
                return
            }
            visible = false
        }
        onVisibleChanged: {
            if (visible) {
                // Always claim activation on show (systemtray pattern): it
                // makes keyboard navigation work, and an inactive popup would
                // receive no deactivation when the user clicks elsewhere, so
                // outside clicks could never close it. The stale-deactivate
                // artifact from popup switches is handled by the grace
                // window in onActiveChanged.
                requestActivate()
                openedAt = Date.now()
            } else {
                activityRefresh.stop()
                launcher.closeApplicationContextMenu()
                if (root.activeButton) root.activeButton.forceActiveFocus()
                root.activeStackId = ""
            }
        }
        mainItem: GroupStackContent {
            id: stackMenu
            launcher: root.menuLauncher
            taskArea: root.taskArea
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
        onCloseWindowRequested: desktopId => {
            // Polite window close through the live task bridge; a degraded
            // widget (no taskArea) ignores the request.
            if (!root.taskArea) return
            root.taskArea.close(desktopId)
        }
    }
    function configure() {
        const action = Plasmoid.internalAction("configure")
        if (action) action.trigger()
    }
    // TaskArea brings the live window database; loading it dynamically
    // degrades to launcher-only mode wherever its module is unavailable.
    Loader {
        id: taskLoader
        active: Plasmoid.configuration.taskTrackingEnabled
        sourceComponent: Component { TaskArea { desktopIds: root.desktopIds } }
    }
    fullRepresentation: Item {
        id: content
        readonly property real cellSize: root.onPanel
            ? Math.max(1, root.vertical ? root.width : root.height)
            : Kirigami.Units.gridUnit * 2
        readonly property int count: Math.max(1, root.panelItems.length)
        implicitWidth: root.vertical ? cellSize : count * cellSize
        implicitHeight: root.vertical ? count * cellSize : cellSize
        // Only constrain the panel's long axis; Plasma owns its thickness.
        Layout.minimumWidth: root.vertical ? 0 : implicitWidth
        Layout.minimumHeight: root.vertical ? implicitHeight : 0
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        readonly property real panelIconSize: Math.max(1, Math.min(Kirigami.Units.iconSizes.large,
            cellSize - Kirigami.Units.smallSpacing * 2))
        function focusEntry(index) {
            if (buttons.count) buttons.itemAt((index + buttons.count) % buttons.count).forceActiveFocus()
        }
        GridLayout {
            anchors.centerIn: parent
            width: content.implicitWidth
            height: content.implicitHeight
            columns: root.vertical ? 1 : content.count
            rowSpacing: 0
            columnSpacing: 0
            PlasmaComponents.ToolButton {
                visible: root.panelItems.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon.name: root.decoded.error ? "dialog-warning" : "view-grid"
                icon.width: content.panelIconSize
                icon.height: content.panelIconSize
                Accessible.name: i18n("Configure %1", root.displayName)
                onClicked: root.configure()
            }
            Repeater {
                id: buttons
                model: root.panelItems
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
                    onActivityEntriesChanged: if (activityEntries.length)
                        root.rememberActivityIds(modelData.id, activityEntries.map(entry => entry.id))
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
                    // Live window state for application and task buttons
                    // (idle defaults otherwise); touching taskArea.revision
                    // keeps it fresh — stateFor walks the model on every call.
                    readonly property var taskState: {
                        if (!root.taskArea || (modelData.type !== "application" && modelData.type !== "task"))
                            return {running: false, active: false, minimized: false, count: 0}
                        root.taskArea.revision
                        return root.taskArea.stateFor(modelData.desktopId)
                    }
                    // Stack button: true when any member app is running. The
                    // touches below refresh it when the member list or task
                    // state changes; stackDesktopIds and stateFor hide their
                    // reads from the binding.
                    readonly property bool memberRunning: {
                        if (modelData.type !== "stack" || !root.taskArea) return false
                        root.taskArea.revision
                        root.catalog
                        root.activityIds
                        for (const id of root.stackDesktopIds(modelData)) {
                            if (root.taskArea.stateFor(id).running) return true
                        }
                        return false
                    }
                    readonly property string appName: {
                        const revision = root.catalogRevision
                        return modelData.type === "stack" ? modelData.settings.groupName || i18n("Stack")
                            : modelData.type === "task" ? modelData.name
                            : modelData.label || (modelData.type === "command" ? modelData.command.name : launcher.name(modelData.desktopId) || modelData.desktopId)
                    }
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: content.cellSize
                    Layout.preferredHeight: content.cellSize
                    activeFocusOnTab: true
                    display: QQC2.AbstractButton.IconOnly
                    text: appName
                    readonly property int requestedIconSize: GroupItems.panelSize(modelData, Plasmoid.configuration.panelIconSize)
                    readonly property real launcherIconSize: requestedIconSize
                        ? Math.max(1, Math.min(requestedIconSize, content.cellSize))
                        : content.panelIconSize
                    readonly property string resolvedIcon: {
                        const revision = root.catalogRevision
                        return modelData.type === "stack" ? modelData.settings.groupIcon || "applications-all"
                            : modelData.type === "task" ? modelData.icon || "application-x-executable"
                            : modelData.icon || (modelData.type === "command" ? "application-x-executable" : launcher.icon(modelData.desktopId) || "application-x-executable")
                    }
                    icon.name: IconOverrides.isFile(resolvedIcon) ? "" : resolvedIcon
                    icon.source: IconOverrides.isFile(resolvedIcon) ? resolvedIcon : ""
                    icon.color: "transparent"
                    contentItem: Item {
                        implicitWidth: button.launcherIconSize
                        implicitHeight: button.launcherIconSize
                        ApplicationIcon {
                            anchors.centerIn: parent
                            width: Math.min(button.requestedIconSize ? button.width : parent.width, button.launcherIconSize)
                            height: Math.min(button.requestedIconSize ? button.height : parent.height, button.launcherIconSize)
                            roundToIconSize: button.requestedIconSize === 0
                            source: button.resolvedIcon
                            fallbackSource: button.modelData.type === "application" ? launcher.icon(button.modelData.desktopId) || "application-x-executable"
                                : button.modelData.type === "command" || button.modelData.type === "task" ? "application-x-executable" : "applications-all"
                            sourceAvailable: { const revision = root.catalogRevision; return launcher.themeIconAvailable(source) }
                        }
                    }
                    icon.width: button.launcherIconSize
                    icon.height: button.launcherIconSize
                    highlighted: (stackPopup.visible && root.activeStackId === modelData.id) || taskState.active
                    Accessible.name: appName
                    onClicked: {
                        root.launchError = ""
                        if (modelData.type === "stack") root.showStack(button, true)
                        else {
                            stackPopup.visible = false
                            if (modelData.type === "command") launcher.activateEntry({source: "applications", action: "launchCommand",
                                target: modelData.command.executable, arguments: modelData.command.arguments})
                            else root.clickTask(modelData)
                        }
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
                    // Right-click: the native app menu — published desktop
                    // actions, plus Close while the app has live windows — for
                    // direct launchers and appended running-app buttons. Stacks
                    // and custom commands have no menu (no service, no task).
                    MouseArea {
                        anchors.fill: parent
                        enabled: ClickMatrix.offersContextMenu(button.modelData)
                        acceptedButtons: Qt.RightButton
                        onClicked: launcher.showEntryContextMenu(button,
                            launcher.applicationEntry(button.modelData.desktopId),
                            button.taskState.running)
                    }
                    // Middle-click opens a new window (or launches an idle
                    // app); the wheel steps through the app's windows. Stacks
                    // and commands keep their plain behavior.
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.taskArea !== null
                            && (button.modelData.type === "application" || button.modelData.type === "task")
                        acceptedButtons: Qt.MiddleButton
                        onClicked: root.newTaskInstance(button.modelData)
                        onWheel: wheel => root.taskArea.step(button.modelData.desktopId,
                            wheel.angleDelta.y > 0 ? 1 : -1)
                    }
                    // Running indicator: active windows light the dot up;
                    // stack buttons show it dimmed when any member app runs.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.max(1, Math.round(parent.height / 24))
                        width: Math.max(3, Math.round(parent.height / 10))
                        height: width
                        radius: width / 2
                        visible: button.modelData.type === "stack" ? button.memberRunning : button.taskState.running
                        color: button.taskState.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.highlightColor
                        opacity: button.modelData.type === "stack" ? 0.7 : 1
                    }
                    // Window count for apps with grouped windows.
                    PlasmaComponents.Label {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Math.max(1, Math.round(parent.height / 24))
                        visible: button.taskState.count > 1
                        text: button.taskState.count
                        font.pixelSize: Math.max(1, Math.round(Kirigami.Units.gridUnit * 0.5))
                        font.bold: true
                        color: Kirigami.Theme.textColor
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

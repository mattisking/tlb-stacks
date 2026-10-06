import QtQuick
import "MenuNavigation.js" as Navigation
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import com.mattphilmon.truelaunchbar

ColumnLayout {
    id: root
    required property string folderUrl
    required property string filters
    required property bool iconsOnly
    required property int iconSize
    required property int rowHeight
    required property int menuWidth
    property int hoverDelay: 250
    property real initialMenuHeight: rowHeight * 2
    property bool listingReady: false
    property bool listingStarted: false
    signal listingHeightReady(real height)
    signal dismissRequested()
    required property bool popupOpen
    property url currentFolder: folderUrl
    property bool keyboardNavigation: false
    property bool keyboardOwnsSelection: false
    property point keyboardPointerPosition: Qt.point(0, 0)

    function claimKeyboardSelection() {
        keyboardOwnsSelection = true
        keyboardPointerPosition = launcher.pointerPosition()
    }
    function selectPointerRow(entry) {
        keyboardOwnsSelection = false
        keyboardNavigation = false
        highlightedFolderEntry = null
        hoveredIndex = entry.index
        fileList.currentIndex = entry.index
        if (entry.stackEntry.hasChildren) {
            pendingEntry = entry
            folderHover.restart()
        }
    }
    property int hoveredIndex: -1
    property var pendingEntry: null
    property Item highlightedFolderEntry: null
    readonly property bool loading: files.loading
    readonly property bool available: files.available
    property string openError: ""
    readonly property var patterns: filters.split(";").map(value => value.trim()).filter(value => value.length > 0)
    readonly property string notice: openError || files.error ||
        (files.loading && files.entries.length === 0 ? qsTr("Loading…")
        : !available ? qsTr("Folder is unavailable. Choose a folder in configuration.")
        : files.entries.length === 0 ? qsTr("No files match these patterns.") : "")

    spacing: 0
    implicitWidth: menuWidth
    readonly property real populatedMenuHeight: Math.min(Math.max(rowHeight, files.entries.length * rowHeight),
                             Math.min(480, Screen.desktopAvailableHeight * 0.7))
    readonly property real preferredMenuHeight: listingReady ? populatedMenuHeight
        : Math.min(Math.max(rowHeight, initialMenuHeight),
                   Math.min(480, Screen.desktopAvailableHeight * 0.7))
    implicitHeight: preferredMenuHeight

    Launcher {
        id: launcher
        onFolderNavigateRequested: step => root.moveSelection(step)
        onFolderKeyboardEntered: {
            root.claimKeyboardSelection()
            root.keyboardNavigation = false
            root.hoveredIndex = -1
        }
        onFolderDismissRequested: root.dismissRequested()
        onFolderFocusRequested: anchor => {
            if (!anchor) return
            root.claimKeyboardSelection()
            root.hoveredIndex = -1
            Qt.callLater(function() {
                if (!root.popupOpen || !anchor) return
                root.keyboardNavigation = true
                root.highlightedFolderEntry = anchor
                fileList.currentIndex = anchor.index
                anchor.forceActiveFocus(Qt.BacktabFocusReason)
            })
        }
        onActivationFailed: message => { root.openError = message }
        onFolderAnchorHighlightChanged: anchor => { root.highlightedFolderEntry = anchor }
    }

    function resetFolder() {
        launcher.closeFolderMenu()
        currentFolder = folderUrl
        openError = ""
    }
    onFolderUrlChanged: { listingReady = false; resetFolder() }
    onPopupOpenChanged: {
        folderHover.stop()
        if (popupOpen) {
            resetFolder()
            keyboardNavigation = false
            keyboardOwnsSelection = false
            hoveredIndex = -1
            fileList.currentIndex = -1
            Qt.callLater(function() { if (root.popupOpen) root.forceActiveFocus() })
        }
        else { launcher.closeFolderMenu(); launcher.closeApplicationContextMenu() }
    }
    onFiltersChanged: { listingReady = false; launcher.closeFolderMenu() }
    Component.onDestruction: { launcher.closeFolderMenu(); launcher.closeApplicationContextMenu() }

    function moveSelection(step) {
        folderHover.stop()
        launcher.closeFolderMenu()
        if (fileList.count === 0) return
        highlightedFolderEntry = null
        const index = Navigation.nextIndex(fileList.count, fileList.currentIndex,
                                           hoveredIndex, keyboardNavigation, step)
        claimKeyboardSelection()
        keyboardNavigation = true
        fileList.currentIndex = index
        fileList.positionViewAtIndex(index, ListView.Contain)
        if (fileList.currentItem) {
            fileList.currentItem.forceActiveFocus(Qt.TabFocusReason)
            if (fileList.currentItem.stackEntry.hasChildren) {
                pendingEntry = fileList.currentItem
                folderHover.restart()
            }
        }
    }

    Keys.onDownPressed: event => { moveSelection(1); event.accepted = true }
    Keys.onUpPressed: event => { moveSelection(-1); event.accepted = true }
    Keys.onRightPressed: event => {
        if (fileList.currentIndex < 0) moveSelection(1)
        openSubfolder(fileList.currentItem, true)
        event.accepted = true
    }

    function openSubfolder(entry, keyboard = false) {
        if (!popupOpen || !entry || !entry.stackEntry.hasChildren) return
        folderHover.stop()
        if (keyboard) {
            claimKeyboardSelection()
            keyboardNavigation = false
            hoveredIndex = -1
        }
        launcher.showFolderMenu(entry, entry.stackEntry.target, root.patterns, root.hoverDelay, keyboard, root.keyboardNavigation && !keyboard)
    }
    Timer {
        id: folderHover
        interval: root.hoverDelay
        onTriggered: {
            const entry = root.pendingEntry
            if (entry && root.keyboardNavigation && fileList.currentItem === entry)
                root.openSubfolder(entry, false)
            else if (entry && entry.hovered) root.openSubfolder(entry)
        }
    }
    Component.onCompleted: resetFolder()

    FolderSource {
        id: files
        folder: root.currentFolder
        filters: root.patterns
        active: root.popupOpen
        onEntriesChanged: launcher.closeFolderMenu()
        onStateChanged: {
            if (loading) root.listingStarted = true
            else if (active && root.listingStarted) {
                root.listingStarted = false
                root.listingReady = true
                root.listingHeightReady(root.populatedMenuHeight)
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.notice.length > 0
        text: root.iconsOnly ? "…" : root.notice
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        Accessible.name: root.notice
        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: root.notice
            textFormat: Text.PlainText
            active: root.popupOpen
        }
    }

    PlasmaComponents.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.available
        ListView {
            id: fileList
            clip: true
            keyNavigationEnabled: false
            Keys.forwardTo: [root]
            model: files.entries
            onCountChanged: { currentIndex = -1; launcher.closeFolderMenu() }
            onMovementStarted: launcher.closeFolderMenu()
            delegate: PlasmaComponents.ItemDelegate {
                id: entry
                required property int index
                required property var modelData
                readonly property var stackEntry: modelData
                width: ListView.view.width
                height: root.rowHeight
                text: stackEntry.name
                Accessible.name: stackEntry.name
                contentItem: RowLayout {
                    ApplicationIcon {
                        source: entry.stackEntry.icon
                        Layout.preferredWidth: root.iconSize
                        Layout.preferredHeight: root.iconSize
                        Layout.fillWidth: root.iconsOnly
                    }
                    PlasmaComponents.Label {
                        visible: !root.iconsOnly
                        Layout.fillWidth: true
                        text: entry.stackEntry.name + (entry.stackEntry.hasChildren ? "  ›" : "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
                onClicked: {
                    tooltip.hideToolTip()
                    root.openError = ""
                    if (stackEntry.hasChildren) {
                        root.openSubfolder(entry)
                    } else {
                        launcher.activateEntry(stackEntry)
                    }
                }
                highlighted: root.highlightedFolderEntry === entry
                    || (root.keyboardNavigation && ListView.isCurrentItem)
                hoverEnabled: true
                onHoveredChanged: {
                    // Popup grabs can recompute hover without any pointer movement.
                    // Those notifications must not replace keyboard selection.
                    if (hovered && !root.keyboardOwnsSelection) root.selectPointerRow(entry)
                    else if (!hovered && root.hoveredIndex === index) root.hoveredIndex = -1
                    if (!hovered && !root.keyboardOwnsSelection && root.pendingEntry === entry) {
                        folderHover.stop()
                        root.pendingEntry = null
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.RightButton
                    onPositionChanged: mouse => {
                        if (!containsMouse) return
                        const position = mapToGlobal(mouse.x, mouse.y)
                        if (!root.keyboardOwnsSelection
                                || position.x !== root.keyboardPointerPosition.x
                                || position.y !== root.keyboardPointerPosition.y)
                            root.selectPointerRow(entry)
                    }
                    onClicked: {
                        root.selectPointerRow(entry)
                        folderHover.stop()
                        tooltip.hideToolTip()
                        launcher.showEntryContextMenu(entry, entry.stackEntry)
                    }
                }
                Keys.onMenuPressed: event => {
                    tooltip.hideToolTip()
                    launcher.showEntryContextMenu(entry, entry.stackEntry)
                    event.accepted = true
                }
                Keys.onRightPressed: root.openSubfolder(entry, true)
                Component.onDestruction: {
                    if (root.highlightedFolderEntry === entry) root.highlightedFolderEntry = null
                    if (root.pendingEntry === entry) {
                        folderHover.stop()
                        root.pendingEntry = null
                    }
                }
                StackToolTip {
                    id: tooltip
                    anchors.fill: parent
                    text: entry.stackEntry.name
                    selected: root.popupOpen
                        && root.highlightedFolderEntry !== entry
                        && (root.keyboardOwnsSelection
                            ? root.keyboardNavigation && fileList.currentIndex === entry.index
                            : entry.hovered)
                }
            }
        }
    }
}

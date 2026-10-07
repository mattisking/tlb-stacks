pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import com.mattphilmon.tlbstacks

ColumnLayout {
    id: content
    required property var launcher
    property var entries: []
    property bool iconsOnly: false
    property int iconSize: 22
    property bool popupOpen: false
    property string errorText: ""
    property string menuSource: "applications"
    property string folderUrl: ""
    property string folderFilters: "*"
    property int hoverDelay: 250
    property string emptyText: i18n("Add applications in group configuration.")
    property real initialFolderHeight: 80
    signal folderHeightReady(real height)
    readonly property bool isFolder: menuSource === "folder"
    signal dismissRequested()
    signal activating()
    signal activated()

    // Plasma Dialog sizes its native window from mainItem's actual size, not
    // only a layout's implicit size. Compute from entries before delegates settle.
    readonly property real rowsHeight: entries.reduce((total, entry) => total + menu.entryHeight(entry), 0)
    readonly property real requestedHeight: Math.max(40,
        (isFolder ? (folderLoader.item ? folderLoader.item.preferredMenuHeight : initialFolderHeight)
            : entries.length ? Math.min(rowsHeight, 480) : emptyNotice.implicitHeight)
        + (errorText.length ? errorNotice.implicitHeight : 0))
    width: iconsOnly && !isFolder ? Math.max(40, iconSize + 16) : 260
    height: requestedHeight
    Layout.minimumHeight: requestedHeight
    Layout.maximumHeight: requestedHeight
    spacing: 0
    function resetSelection() {
        if (isFolder) {
            if (folderLoader.item && popupOpen) folderLoader.item.forceActiveFocus()
        } else menu.resetSelection()
    }
    Keys.onEscapePressed: dismissRequested()
    Keys.onLeftPressed: dismissRequested()
    Loader {
        id: folderLoader
        active: content.isFolder
        visible: active
        Layout.fillWidth: true
        Layout.minimumHeight: item ? item.preferredMenuHeight : content.initialFolderHeight
        Layout.maximumHeight: Layout.minimumHeight
        sourceComponent: FolderMenu {
            folderUrl: content.folderUrl
            filters: content.folderFilters
            iconsOnly: false
            iconSize: content.iconSize
            rowHeight: Math.max(40, content.iconSize + 16)
            menuWidth: content.width
            hoverDelay: content.hoverDelay
            popupOpen: content.popupOpen
            initialMenuHeight: content.initialFolderHeight
            onListingHeightReady: height => content.folderHeightReady(height)
            onDismissRequested: content.dismissRequested()
        }
    }
    PlasmaComponents.Label {
        id: emptyNotice
        Layout.fillWidth: true
        visible: !content.isFolder && content.entries.length === 0
        text: content.emptyText
        wrapMode: Text.WordWrap
    }
    PlasmaComponents.Label {
        id: errorNotice
        Layout.fillWidth: true
        visible: content.errorText.length > 0
        text: content.errorText
        wrapMode: Text.WordWrap
    }
    ApplicationMenu {
        id: menu
        launcher: content.launcher
        entries: content.entries
        iconsOnly: content.iconsOnly
        iconSize: content.iconSize
        popupOpen: content.popupOpen
        visible: !content.isFolder && content.entries.length > 0
        Layout.minimumHeight: Math.min(content.rowsHeight, 480)
        Layout.maximumHeight: Math.min(content.rowsHeight, 480)
        onActivating: content.activating()
        onActivated: content.activated()
    }
}

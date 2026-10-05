import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQml.Models
import Qt.labs.folderlistmodel

QQC2.Menu {
    id: root
    required property url folderUrl
    required property var patterns
    required property var backend
    required property int iconSize
    required property int rowHeight
    required property int menuWidth
    required property bool iconsOnly
    property bool available: false
    property var childMenus: []
    readonly property bool pointerInside: {
        for (let i = 0; i < count; ++i) {
            const item = itemAt(i)
            if (item && item.hovered) return true
        }
        return false
    }

    // Separate windows can extend past the narrow parent popup. Qt handles
    // cascading, submenu hover timing, keyboard navigation and screen edges.
    popupType: QQC2.Popup.Window
    cascade: true
    modal: false
    width: menuWidth
    height: Math.min(implicitHeight, 480, Math.max(rowHeight * 2, contentItem.Screen.desktopAvailableHeight * 0.7))
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        currentIndex: root.currentIndex
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollIndicator.vertical: QQC2.ScrollIndicator {}
    }

    function pointerInBranch() {
        return visible && (pointerInside || childMenus.some(menu => menu && menu.pointerInBranch()))
    }

    function addEntry(index, record) {
        if (record.fileIsDir) {
            const menu = Qt.createComponent("FolderCascadeMenu.qml").createObject(root, {
                folderUrl: record.fileUrl, patterns: root.patterns, backend: root.backend,
                iconSize: root.iconSize, rowHeight: root.rowHeight,
                menuWidth: root.menuWidth, iconsOnly: root.iconsOnly,
                title: record.fileName
            })
            if (!menu) return
            menu.icon.name = "folder"
            record.entry = menu
            root.childMenus = root.childMenus.concat([menu])
            root.insertMenu(index, menu)
        } else {
            const item = fileItem.createObject(root.contentItem, {
                text: record.fileName, fileUrl: record.fileUrl
            })
            if (!item) return
            record.entry = item
            root.insertItem(index, item)
        }
    }

    function removeEntry(record) {
        if (!record.entry) return
        if (record.fileIsDir) {
            root.childMenus = root.childMenus.filter(menu => menu !== record.entry)
            root.removeMenu(record.entry)
        } else {
            root.removeItem(record.entry)
            record.entry.destroy()
        }
        record.entry = null
    }

    onAboutToShow: available = backend.folderAvailable(folderUrl)

    FolderListModel {
        id: files
        folder: root.folderUrl
        nameFilters: root.patterns.length ? root.patterns : ["*"]
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        sortCaseSensitive: false
    }

    // Only populate the open level. Closed submenus never recursively build
    // a directory tree, including when a symlink points back to an ancestor.
    Instantiator {
        active: root.visible && root.available
        model: files
        delegate: QtObject {
            required property string fileName
            required property url fileUrl
            required property bool fileIsDir
            property var entry: null
        }
        onObjectAdded: (index, object) => root.addEntry(index, object)
        onObjectRemoved: (index, object) => root.removeEntry(object)
    }

    delegate: QQC2.MenuItem {
        id: directoryItem
        hoverEnabled: true
        height: root.rowHeight
        icon.width: root.iconSize
        icon.height: root.iconSize
        display: root.iconsOnly ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
        Accessible.name: text
        QQC2.ToolTip {
            text: directoryItem.text
            visible: root.visible && root.iconsOnly && directoryItem.hovered
            popupType: QQC2.Popup.Window
            delay: 500
        }
    }

    Component {
        id: fileItem
        QQC2.MenuItem {
            id: fileEntry
            hoverEnabled: true
            required property url fileUrl
            height: root.rowHeight
            icon.name: root.backend.fileIcon(fileUrl)
            icon.width: root.iconSize
            icon.height: root.iconSize
            display: root.iconsOnly ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
            Accessible.name: text
            onTriggered: root.backend.openFile(fileUrl)
            QQC2.ToolTip {
                text: fileEntry.text
                visible: root.visible && fileEntry.hovered
                popupType: QQC2.Popup.Window
                delay: 500
            }
        }
    }

    QQC2.MenuItem {
        visible: !root.available || files.status === FolderListModel.Loading || files.count === 0
        height: visible ? root.rowHeight : 0
        enabled: false
        text: !root.available ? qsTr("Folder unavailable")
            : files.status === FolderListModel.Loading ? qsTr("Loading…") : qsTr("No matching files")
    }
}

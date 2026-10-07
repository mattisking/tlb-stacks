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
    signal dismissRequested()
    signal activating()
    signal activated()

    // Plasma Dialog sizes its native window from mainItem's actual size, not
    // only a layout's implicit size. Compute from entries before delegates settle.
    readonly property real rowsHeight: entries.reduce((total, entry) => total + menu.entryHeight(entry), 0)
    readonly property real requestedHeight: Math.max(40,
        (entries.length ? Math.min(rowsHeight, 480) : emptyNotice.implicitHeight)
        + (errorText.length ? errorNotice.implicitHeight : 0))
    width: iconsOnly ? Math.max(40, iconSize + 16) : 260
    height: requestedHeight
    Layout.minimumHeight: requestedHeight
    Layout.maximumHeight: requestedHeight
    spacing: 0
    function resetSelection() { menu.resetSelection() }
    Keys.onEscapePressed: dismissRequested()
    Keys.onLeftPressed: dismissRequested()
    PlasmaComponents.Label {
        id: emptyNotice
        Layout.fillWidth: true
        visible: content.entries.length === 0
        text: i18n("Add applications in group configuration.")
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
        visible: content.entries.length > 0
        Layout.minimumHeight: Math.min(content.rowsHeight, 480)
        Layout.maximumHeight: Math.min(content.rowsHeight, 480)
        onActivating: content.activating()
        onActivated: content.activated()
    }
}

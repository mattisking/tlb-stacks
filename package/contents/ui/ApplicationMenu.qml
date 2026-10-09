pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "MenuNavigation.js" as Navigation
import "IconOverrides.js" as IconOverrides

PlasmaComponents.ScrollView {
    id: applicationScroll
    required property var launcher
    property var entries: []
    property bool iconsOnly: false
    property int iconSize: 22
    property bool popupOpen: false
    // Live window bridge (null when unavailable or degraded): running
    // entries mirror their window state and activate it instead of launching.
    property var taskArea: null
    readonly property real menuContentHeight: applicationColumn.implicitHeight
    signal activating()
    signal activated()
    function entryHeight(entry) {
        return entry.isSeparator !== true ? Math.max(40, iconSize + 16)
            : !iconsOnly && entry.name ? 28 : 10
    }
    function resetSelection() {
        selectedApplication = -1
        hoveredApplication = -1
        keyboardNavigation = false
        if (popupOpen) Qt.callLater(() => { if (popupOpen) forceActiveFocus() })
    }
    onPopupOpenChanged: resetSelection()
    onEntriesChanged: resetSelection()

    property int selectedApplication: -1
    property int hoveredApplication: -1
    property bool keyboardNavigation: false

    function moveApplicationSelection(step) {
        const index = Navigation.nextIndex(applicationRepeater.count, selectedApplication,
            hoveredApplication, keyboardNavigation, step,
            applicationScroll.entries.map(entry => entry.isSeparator !== true))
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
        moveApplicationSelection(-1); event.accepted = true
    }
    Keys.onDownPressed: event => {
        moveApplicationSelection(1); event.accepted = true
    }
    contentWidth: availableWidth
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(applicationColumn.implicitHeight, 480)
    ColumnLayout {
        id: applicationColumn
        width: applicationScroll.availableWidth
        spacing: 0
        Repeater {
            id: applicationRepeater
            model: applicationScroll.entries
            onCountChanged: applicationScroll.selectedApplication = -1

            delegate: PlasmaComponents.ItemDelegate {
                id: launcherItem

                required property int index
                required property var modelData

                objectName: "menuEntry-" + modelData.id

                readonly property string applicationName:
                    modelData.isSeparator === true ? "" : modelData.name

                readonly property string applicationIcon:
                    modelData.isSeparator === true ? "" : modelData.icon

                // Live task state for this entry (idle defaults without a
                // taskArea). Touching taskArea.revision keeps it fresh —
                // stateFor walks the live tasks model on every call.
                readonly property var taskState: {
                    const area = applicationScroll.taskArea
                    if (!area || modelData.isSeparator === true)
                        return {running: false, active: false, minimized: false, count: 0}
                    area.revision
                    return area.stateFor(modelData.id)
                }

                visible: modelData.available

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.maximumWidth: applicationScroll.availableWidth

                implicitHeight: applicationScroll.entryHeight(modelData)
                Layout.minimumHeight: applicationScroll.entryHeight(modelData)
                Layout.preferredHeight: applicationScroll.entryHeight(modelData)
                Layout.maximumHeight: applicationScroll.entryHeight(modelData)
                enabled: modelData.isSeparator !== true
                hoverEnabled: modelData.isSeparator !== true

                text: applicationName
                icon.name: IconOverrides.isFile(applicationIcon) ? "" : applicationIcon
                icon.source: IconOverrides.isFile(applicationIcon) ? applicationIcon : ""
                icon.width: applicationScroll.iconSize
                icon.height: applicationScroll.iconSize
                display: applicationScroll.iconsOnly ? QQC2.AbstractButton.IconOnly
                                        : QQC2.AbstractButton.TextBesideIcon
                contentItem: RowLayout {
                    spacing: launcherItem.spacing
                    Rectangle {
                        visible: launcherItem.modelData.isSeparator === true
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents.Label {
                        visible: launcherItem.modelData.isSeparator === true &&
                                 !applicationScroll.iconsOnly && text.length > 0
                        text: launcherItem.modelData.name
                        elide: Text.ElideRight
                        opacity: 0.7
                        font.bold: true
                        Layout.maximumWidth: Math.max(0, launcherItem.width * 0.6)
                    }
                    Rectangle {
                        visible: launcherItem.modelData.isSeparator === true &&
                                 !applicationScroll.iconsOnly && launcherItem.modelData.name.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Kirigami.Theme.disabledTextColor
                    }
                    ApplicationIcon {
                        visible: launcherItem.modelData.isSeparator !== true
                        source: launcherItem.applicationIcon
                        sourceAvailable: fromFile || applicationScroll.launcher.themeIconAvailable(source)
                        fallbackSource: launcherItem.modelData.defaultIcon || ""
                        Layout.preferredWidth: applicationScroll.iconSize
                        Layout.preferredHeight: applicationScroll.iconSize
                        Layout.alignment: Qt.AlignCenter
                        Layout.fillWidth: applicationScroll.iconsOnly
                    }
                    // Running dot beside the icon: an active window lights it up.
                    Rectangle {
                        objectName: "runningDot"
                        visible: launcherItem.taskState.running
                        Layout.preferredWidth: Math.max(4, Math.round(applicationScroll.iconSize / 4))
                        Layout.preferredHeight: Math.max(4, Math.round(applicationScroll.iconSize / 4))
                        radius: width / 2
                        color: launcherItem.taskState.active
                            ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.highlightColor
                    }
                    PlasmaComponents.Label {
                        visible: !applicationScroll.iconsOnly && launcherItem.modelData.isSeparator !== true
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: launcherItem.applicationName
                        elide: Text.ElideRight
                    }
                    // Window count for apps with grouped windows.
                    PlasmaComponents.Label {
                        objectName: "countBadge"
                        visible: launcherItem.taskState.count > 1
                        text: launcherItem.taskState.count
                        font.pixelSize: Math.max(1, Math.round(Kirigami.Units.gridUnit * 0.5))
                        font.bold: true
                        color: Kirigami.Theme.textColor
                    }
                }
                Keys.onUpPressed: applicationScroll.moveApplicationSelection(-1)
                Keys.onDownPressed: applicationScroll.moveApplicationSelection(1)
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                highlighted: applicationScroll.keyboardNavigation && applicationScroll.selectedApplication === index
                onHoveredChanged: {
                    if (hovered) {
                        applicationScroll.hoveredApplication = index
                        applicationScroll.keyboardNavigation = false
                    } else if (applicationScroll.hoveredApplication === index) applicationScroll.hoveredApplication = -1
                }
                Accessible.name: modelData.isSeparator === true
                    ? i18n("Separator") : applicationName || modelData.id

                StackToolTip {
                    id: applicationToolTip
                    anchors.fill: parent
                    text: (launcherItem.applicationName || launcherItem.modelData.id)
                        + (launcherItem.modelData.description ? "\n" + launcherItem.modelData.description : "")
                    selected: applicationScroll.popupOpen && launcherItem.visible
                        && (applicationScroll.keyboardNavigation
                            ? applicationScroll.selectedApplication === launcherItem.index
                            : launcherItem.hovered)
                }

                // Consume only right-clicks; normal activation stays with the delegate.
                MouseArea {
                    anchors.fill: parent
                    enabled: launcherItem.modelData.isSeparator !== true
                        && launcherItem.modelData.actions.length > 0
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        applicationToolTip.hideToolTip()
                        applicationScroll.launcher.showEntryContextMenu(launcherItem, launcherItem.modelData)
                    }
                }
                // Consume only middle-clicks — ItemDelegate never fires on
                // them: a running app opens a new window, an idle one
                // launches. Without a taskArea the area stays disabled, so
                // launcher-only consumers keep the middle-click no-op.
                MouseArea {
                    anchors.fill: parent
                    enabled: applicationScroll.taskArea !== null
                        && launcherItem.modelData.isSeparator !== true
                    acceptedButtons: Qt.MiddleButton
                    onClicked: {
                        applicationScroll.activating()
                        const area = applicationScroll.taskArea
                        if (area && area.newInstance(launcherItem.modelData.id)) {
                            applicationScroll.activated()
                            return
                        }
                        if (applicationScroll.launcher.activateEntry(launcherItem.modelData)) {
                            applicationScroll.activated()
                        }
                    }
                }
                Keys.onMenuPressed: event => {
                    if (launcherItem.modelData.actions.length > 0) {
                        applicationToolTip.hideToolTip()
                        applicationScroll.launcher.showEntryContextMenu(launcherItem, launcherItem.modelData)
                        event.accepted = true
                    }
                }

                onClicked: {
                    if (modelData.isSeparator === true) return
                    applicationScroll.activating()
                    // A running app activates its window instead of launching;
                    // commands never match a desktop id, so they stay launch-only.
                    const area = applicationScroll.taskArea
                    if (area && area.activate(modelData.id)) {
                        applicationScroll.activated()
                        return
                    }
                    if (applicationScroll.launcher.activateEntry(modelData)) {
                        applicationScroll.activated()
                    }
                }
            }
        }
    }
}

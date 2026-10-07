pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
import org.kde.plasma.components as PlasmaComponents
import "IconOverrides.js" as IconOverrides

// One stack's settings editor, shared by the group host (tree + preview)
// and the standalone host (opened directly). Pure data in, partial changes
// out: the host persists `changes` through its own storage. Never touches
// cfg_* properties or the groupSelection handoff.
ColumnLayout {
    id: root

    property var settings: ({})
    property var catalog: []
    property var launcher: null
    property string stackIconDefault: "applications-all"
    signal settingsEdited(var changes)

    readonly property var kinds: [
        { id: "applications", label: i18n("Selected"),  icon: "view-list-icons" },
        { id: "folder",       label: i18n("Live folder"), icon: "folder" },
        { id: "categories",   label: i18n("Categories"),  icon: "tag" },
        { id: "activity",     label: i18n("Recent"),      icon: "document-open-recent" }
    ]
    readonly property string menuSource: settings.menuSource || "applications"
    // Group-decoded stacks carry applicationIcons as an object; the single
    // host's cfg_applicationIcons is a JSON string. Accept both.
    readonly property var applicationIcons: (typeof settings.applicationIcons === "object"
        && settings.applicationIcons !== null && !Array.isArray(settings.applicationIcons))
        ? settings.applicationIcons : IconOverrides.parse(settings.applicationIcons || "{}")

    function setKind(kind) { settingsEdited({menuSource: kind}) }
    function setField(key, value) { const c = {}; c[key] = value; settingsEdited(c) }

    // ---- icon flow (Choose… / Image… / Reset, per existing single-host behavior)
    property string iconTarget: ""   // "" = the stack icon; otherwise a desktopId
    property var iconPending: null

    function chooseIcon(target, fromFile) {
        iconTarget = target
        if (fromFile) iconFileDialog.open()
        else {
            stackIconDialog.title = target ? i18n("Choose an application icon") : i18n("Choose a stack icon")
            stackIconDialog.open()
        }
    }
    function setCustomIcon(target, icon) {
        if (!launcher || launcher.profileBusy) return
        iconPending = {id: launcher.profileOperation("manageIcon", {icon: icon}), target: target}
    }
    function applyIconResult(target, icon) {
        if (!target) { settingsEdited({groupIcon: icon || stackIconDefault}); return }
        const icons = Object.assign({}, applicationIcons)
        if (icon) icons[target] = icon; else delete icons[target]
        settingsEdited({applicationIcons: icons})
    }
    Connections {
        target: root.launcher
        function onProfileFinished(requestId, result) {
            if (!root.iconPending || root.iconPending.id !== requestId) return
            const target = root.iconPending.target
            root.iconPending = null
            if (result.ok) root.applyIconResult(target, result.icon)
        }
    }
    IconThemes.IconDialog { id: stackIconDialog; onIconNameChanged: if (iconName.length > 0) root.applyIconResult(root.iconTarget, iconName) }
    Dialogs.FileDialog {
        id: iconFileDialog
        title: i18n("Choose an icon image")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("Icon images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.ico)")]
        onAccepted: {
            const url = selectedFile.toString()
            if (url.startsWith("file://"))
                root.setCustomIcon(root.iconTarget, decodeURIComponent(url.substring(7)))
        }
    }

    // ---- kind segments (mockup: icon over label, highlighted active)
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: root.kinds
            delegate: PlasmaComponents.ToolButton {
                id: segment
                required property var modelData
                objectName: "kind-" + modelData.id
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                display: QQC2.AbstractButton.TextUnderIcon
                text: modelData.label
                icon.name: modelData.icon
                checked: root.menuSource === modelData.id
                Accessible.name: i18n("Stack type %1", modelData.label)
                onClicked: root.setKind(modelData.id)
            }
        }
    }

    QQC2.TabBar {
        id: tabs
        Layout.fillWidth: true
        QQC2.TabButton { text: i18n("Contents") }
        QQC2.TabButton { text: i18n("Appearance") }
    }

    // StackLayout is a QtQuick.Layouts type, not a QtQuick.Controls type.
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabs.currentIndex

        // Contents (Task 6 fills this placeholder container — the four source
        // pages live in `contentsPages` below once implemented).
        Item { id: contentsPages; Layout.fillWidth: true; Layout.fillHeight: true }

        // ---- Appearance (Flickable so it scrolls independently of the tree)
        // Flickable is a QtQuick type, not a QtQuick.Controls type.
        Flickable {
            contentWidth: width
            contentHeight: appearanceForm.implicitHeight
            clip: true
            Kirigami.FormLayout {
                id: appearanceForm
                width: parent.width
                PlasmaComponents.TextField {
                    Kirigami.FormData.label: i18n("Name:")
                    text: root.settings.groupName || ""
                    placeholderText: i18n("Stack name")
                    maximumLength: 256
                    onTextEdited: root.setField("groupName", text)
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Icon:")
                    Kirigami.Icon {
                        source: root.settings.groupIcon || root.stackIconDefault
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                    }
                    PlasmaComponents.Button { text: i18n("Choose…"); onClicked: root.chooseIcon("", false) }
                    PlasmaComponents.Button { text: i18n("Image…"); onClicked: root.chooseIcon("", true) }
                    PlasmaComponents.Button {
                        text: i18n("Reset")
                        enabled: root.settings.groupIcon !== root.stackIconDefault
                        onClicked: root.applyIconResult("", "")
                    }
                }
                PlasmaComponents.CheckBox {
                    Kirigami.FormData.label: i18n("Display:")
                    text: root.menuSource === "folder" ? i18n("Icons only (unavailable for Live Folder)")
                        : i18n("Icons only (show names on hover)")
                    enabled: root.menuSource !== "folder"
                    checked: root.settings.iconsOnly || false
                    onToggled: root.setField("iconsOnly", checked)
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Icon size (px):")
                    from: 16; to: 64
                    editable: true
                    value: root.settings.menuIconSize || 22
                    onValueModified: root.setField("menuIconSize", value)
                }
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Hover delay (ms):")
                    from: 0; to: 2000; stepSize: 50
                    editable: true
                    value: root.settings.hoverDelay || 250
                    onValueModified: root.setField("hoverDelay", value)
                }
            }
        }
    }
}

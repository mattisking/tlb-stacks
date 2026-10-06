import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import "IconOverrides.js" as IconOverrides
import "ApplicationCategories.js" as Categories
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
import org.kde.plasma.components as PlasmaComponents
import com.mattphilmon.tlbstacks

ColumnLayout {
    id: root
    enabled: !launcher.profileBusy
    property var pendingProfile: null
    property int catalogRevision: 0

    property string title: i18n("General")
    property alias cfg_groupName: groupNameField.text
    property string cfg_groupNameDefault: ""
    property string cfg_groupIcon: "applications-all"
    property string cfg_groupIconDefault: "applications-all"
    property alias cfg_iconsOnly: iconsOnlyCheck.checked
    property bool cfg_iconsOnlyDefault: false
    property alias cfg_menuIconSize: menuIconSizeField.value
    property int cfg_menuIconSizeDefault: 22
    property alias cfg_hoverDelay: hoverDelayField.value
    property int cfg_hoverDelayDefault: 250
    property string cfg_applicationIcons: "{}"
    property string cfg_applicationIconsDefault: "{}"
    readonly property var applicationIcons: IconOverrides.parse(cfg_applicationIcons)
    // Empty target means the menu icon; otherwise it is a desktop application ID.
    property string iconTarget: ""
    property string cfg_menuSource: "applications"
    property string cfg_menuSourceDefault: "applications"
    property string cfg_activityOrder: "recent"
    property string cfg_activityOrderDefault: "recent"
    property int cfg_activityLimit: 10
    property int cfg_activityLimitDefault: 10
    property bool cfg_activityCurrent: false
    property bool cfg_activityCurrentDefault: false
    property var cfg_applicationCategories: []
    property var cfg_applicationCategoriesDefault: []
    property var categoryApplications: []
    readonly property var availableCategories: Categories.available(categoryApplications, cfg_applicationCategories)
    readonly property var categoryMatches: Categories.matching(categoryApplications, cfg_applicationCategories)
    function toggleCategory(category, enabled) {
        const next = Array.from(cfg_applicationCategories || []).filter(value => value !== category)
        if (enabled) next.push(category)
        cfg_applicationCategories = next
    }
    property string cfg_folderHeightCache: "{}"
    property string cfg_folderHeightCacheDefault: "{}"
    property string cfg_folderUrl: ""
    property string cfg_folderUrlDefault: ""
    property alias cfg_folderFilters: folderFiltersField.text
    property string cfg_folderFiltersDefault: "*"
    property string profileMessage: ""
    property var missingApplications: []
    // Plasma supplies these from main.xml and commits edits on Apply/OK.
    property var cfg_applications: []
    property var cfg_applicationsDefault: []
    readonly property string separatorPrefix: "tlbstacks-separator:"

    Launcher {
        id: launcher
        onApplicationsChanged: {
            root.catalogRevision++
            root.loadApplications()
            root.refreshMissingApplications()
        }
        onProfileFinished: (requestId, result) => root.finishProfile(requestId, result)
    }

    IconThemes.IconDialog {
        id: groupIconDialog
        title: i18n("Choose a menu icon")
        onAccepted: {
            if (iconName.length > 0) {
                root.setCustomIcon(root.iconTarget, iconName)
            }
        }
    }

    Dialogs.FileDialog {
        id: iconFileDialog
        title: i18n("Choose an icon image")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("Icon images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.ico)")]
        onAccepted: {
            const url = selectedFile.toString()
            // Store a local filename, also understood by Plasma's panel icon.
            if (url.startsWith("file://")) {
                root.setCustomIcon(root.iconTarget, decodeURIComponent(url.substring(7)))
            }
        }
    }

    function setCustomIcon(desktopId, icon) {
        root.startProfile("manageIcon", {icon: icon}, desktopId)
    }

    function applyIcon(desktopId, icon) {
        if (!desktopId) {
            root.cfg_groupIcon = icon || root.cfg_groupIconDefault
            return
        }
        const icons = IconOverrides.parse(root.cfg_applicationIcons)
        if (icon) {
            icons[desktopId] = icon
        } else {
            delete icons[desktopId]
        }
        root.cfg_applicationIcons = JSON.stringify(icons)
    }

    function profileSettings() {
        return {
            groupName: root.cfg_groupName,
            groupIcon: root.cfg_groupIcon,
            iconsOnly: root.cfg_iconsOnly,
            menuIconSize: root.cfg_menuIconSize,
            hoverDelay: root.cfg_hoverDelay,
            applications: Array.from(root.cfg_applications),
            applicationIcons: IconOverrides.parse(root.cfg_applicationIcons),
            menuSource: root.cfg_menuSource,
            activityOrder: root.cfg_activityOrder,
            activityLimit: root.cfg_activityLimit,
            activityCurrent: root.cfg_activityCurrent,
            applicationCategories: Array.from(root.cfg_applicationCategories || []),
            folderUrl: root.cfg_folderUrl,
            folderFilters: root.cfg_folderFilters
        }
    }

    Dialogs.FileDialog {
        id: exportProfileDialog
        title: i18n("Export this menu")
        fileMode: Dialogs.FileDialog.SaveFile
        defaultSuffix: "zip"
        nameFilters: [i18n("TLBStacks profile (*.zip)")]
        onAccepted: {
            root.startProfile("export", {
                file: selectedFile.toString(), settings: root.profileSettings()
            }, "")
        }
    }

    Dialogs.FileDialog {
        id: importProfileDialog
        title: i18n("Import a menu into this widget")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("TLBStacks profile (*.zip)")]
        onAccepted: {
            root.startProfile("import", {file: selectedFile.toString()}, "")
        }
    }

    function startProfile(action, request, iconTarget) {
        if (launcher.profileBusy) return
        const id = launcher.profileOperation(action, request)
        root.pendingProfile = {id: id, action: action, iconTarget: iconTarget}
        root.profileMessage = i18n("Working… Please wait before applying changes.")
    }

    function finishProfile(requestId, result) {
        const pending = root.pendingProfile
        if (!pending || pending.id !== requestId) return
        root.pendingProfile = null
        if (!result.ok) { root.profileMessage = result.error; return }
        if (pending.action === "manageIcon") {
            root.applyIcon(pending.iconTarget, result.icon)
            root.profileMessage = ""
        } else if (pending.action === "export") {
            root.profileMessage = i18n("Menu exported with its custom images.")
        } else if (pending.action === "import") {
            const settings = result.settings
            root.cfg_groupName = settings.groupName
            root.cfg_groupIcon = settings.groupIcon
            root.cfg_iconsOnly = settings.iconsOnly
            root.cfg_menuIconSize = settings.menuIconSize
            root.cfg_hoverDelay = settings.hoverDelay
            root.cfg_applicationIcons = JSON.stringify(settings.applicationIcons)
            root.cfg_applications = settings.applications
            root.cfg_applicationCategories = settings.applicationCategories || []
            root.cfg_menuSource = settings.menuSource
            root.cfg_activityOrder = settings.activityOrder || "recent"
            root.cfg_activityLimit = settings.activityLimit || 10
            root.cfg_activityCurrent = settings.activityCurrent || false
            root.cfg_folderUrl = settings.folderUrl
            root.cfg_folderFilters = settings.folderFilters
            root.profileMessage = i18n("Menu imported into the editor. Apply to save, or Cancel to keep your previous menu.")
        }
    }

    function refreshMissingApplications() {
        root.missingApplications = Array.from(root.cfg_applications || [])
            .filter(id => !root.isSeparator(id) && !launcher.exists(id))
    }

    onCfg_applicationsChanged: refreshMissingApplications()

    function isSeparator(id) {
        return typeof id === "string" && id.startsWith(root.separatorPrefix)
    }

    // Separator IDs are "tlbstacks-separator:<number>[:<label>]".
    function separatorNumber(id) {
        const rest = id.slice(root.separatorPrefix.length)
        const colon = rest.indexOf(":")
        return colon < 0 ? rest : rest.slice(0, colon)
    }

    function separatorLabel(id) {
        const rest = id.slice(root.separatorPrefix.length)
        const colon = rest.indexOf(":")
        return colon < 0 ? "" : rest.slice(colon + 1)
    }

    function setSeparatorLabel(index, label) {
        const next = Array.from(root.cfg_applications || [])
        if (index < 0 || index >= next.length || !root.isSeparator(next[index])) return
        const clean = label.trim().slice(0, 64)
        const updated = root.separatorPrefix + root.separatorNumber(next[index]) +
            (clean ? ":" + clean : "")
        if (updated === next[index]) return
        next[index] = updated
        root.cfg_applications = next
    }

    function chooseIcon(desktopId, fromFile) {
        root.iconTarget = desktopId
        if (fromFile) {
            iconFileDialog.open()
        } else {
            groupIconDialog.title = desktopId ? i18n("Choose an application icon") : i18n("Choose a menu icon")
            groupIconDialog.open()
        }
    }

    ListModel {
        id: applicationsModel
    }

    function setApplicationSelected(desktopId, selected) {
        // Assign a new array so Plasma sees the cfg_applications change.
        // Preserve existing order and IDs that are currently unavailable.
        const next = Array.from(root.cfg_applications || [])
        const index = next.indexOf(desktopId)
        if (selected && index === -1) {
            next.push(desktopId)
        } else if (!selected && index !== -1) {
            root.cfg_applications = next.filter(id => id !== desktopId)
            return
        } else {
            return
        }
        root.cfg_applications = next
    }

    function moveApplication(index, offset) {
        const next = Array.from(root.cfg_applications || [])
        const destination = index + offset
        if (index < 0 || index >= next.length ||
                destination < 0 || destination >= next.length) {
            return
        }
        const moved = next.splice(index, 1)[0]
        next.splice(destination, 0, moved)
        root.cfg_applications = next
        selectedApplications.currentIndex = destination
        selectedApplications.positionViewAtIndex(destination, ListView.Contain)
    }

    function insertSeparator() {
        const next = Array.from(root.cfg_applications || [])
        const used = new Set(next.filter(id => root.isSeparator(id)).map(id => root.separatorNumber(id)))
        let number = 1
        while (used.has(String(number))) number++
        const index = selectedApplications.currentIndex >= 0
            ? selectedApplications.currentIndex + 1 : next.length
        next.splice(index, 0, root.separatorPrefix + number)
        root.cfg_applications = next
        selectedApplications.currentIndex = index
        selectedApplications.positionViewAtIndex(index, ListView.Contain)
    }

    function loadApplications() {
        applicationsModel.clear()

        const apps = launcher.applications()
        categoryApplications = apps

        for (const app of apps) {
            applicationsModel.append({
                desktopId: app.desktopId,
                applicationName: app.name,
                applicationIcon: app.icon
            })
        }
    }

    Component.onCompleted: {
        loadApplications()
        refreshMissingApplications()
    }

    RowLayout {
        PlasmaComponents.Button {
            text: i18n("Export menu…")
            icon.name: "document-export"
            onClicked: exportProfileDialog.open()
        }
        PlasmaComponents.Button {
            text: i18n("Import menu…")
            icon.name: "document-import"
            onClicked: importProfileDialog.open()
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.profileMessage.length > 0
        text: root.profileMessage
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.cfg_menuSource === "applications" && root.missingApplications.length > 0
        text: i18n("Unavailable applications (kept in the menu settings): %1", root.missingApplications.join(", "))
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }

    Dialogs.FolderDialog {
        id: folderPicker
        title: i18n("Choose a live menu folder")
        onAccepted: root.cfg_folderUrl = selectedFolder.toString()
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        PlasmaComponents.ComboBox {
            Kirigami.FormData.label: i18n("Menu contents:")
            model: [i18n("Selected applications"), i18n("Live folder"), i18n("Application categories"), i18n("Recent / frequent applications")]
            currentIndex: root.cfg_menuSource === "activity" ? 3 : root.cfg_menuSource === "categories" ? 2 : root.cfg_menuSource === "folder" ? 1 : 0
            onActivated: root.cfg_menuSource = ["applications", "folder", "categories", "activity"][currentIndex]
        }

        PlasmaComponents.ComboBox {
            visible: root.cfg_menuSource === "activity"
            Kirigami.FormData.label: i18n("Order:")
            model: [i18n("Recently used"), i18n("Most frequent")]
            currentIndex: root.cfg_activityOrder === "frequent" ? 1 : 0
            onActivated: root.cfg_activityOrder = currentIndex === 1 ? "frequent" : "recent"
        }
        PlasmaComponents.SpinBox {
            visible: root.cfg_menuSource === "activity"
            Kirigami.FormData.label: i18n("Maximum applications:")
            from: 1; to: 50
            value: root.cfg_activityLimit
            onValueModified: root.cfg_activityLimit = value
        }
        PlasmaComponents.CheckBox {
            visible: root.cfg_menuSource === "activity"
            Kirigami.FormData.label: i18n("Activity scope:")
            text: i18n("Current Activity only")
            checked: root.cfg_activityCurrent
            onToggled: root.cfg_activityCurrent = checked
        }
        ColumnLayout {
            visible: root.cfg_menuSource === "folder"
            Kirigami.FormData.label: i18n("Folder:")
            Layout.fillWidth: true
            Layout.minimumWidth: 0

            PlasmaComponents.Button {
                text: i18n("Choose folder…")
                onClicked: folderPicker.open()
            }

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                // A long path must not determine the form's width.
                implicitWidth: 0
                readOnly: true
                text: root.cfg_folderUrl
                placeholderText: i18n("No folder selected")
                Accessible.name: i18n("Selected folder")
            }
        }

        PlasmaComponents.TextField {
            id: folderFiltersField
            visible: root.cfg_menuSource === "folder"
            Kirigami.FormData.label: i18n("File patterns:")
            placeholderText: "*"
            Keys.onReturnPressed: event => { event.accepted = true }
            Keys.onEnterPressed: event => { event.accepted = true }
        }

        PlasmaComponents.Label {
            visible: root.cfg_menuSource === "folder"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            text: i18n("Separate patterns with semicolons, for example *.pdf;*.desktop. Subfolders are always shown and refresh when reopened. Their contents stay stable while open. Choose a new folder here when importing onto another computer.")
            wrapMode: Text.WordWrap
        }

        PlasmaComponents.TextField {
            id: groupNameField

            Kirigami.FormData.label: "Group name:"
            placeholderText: i18n("Stack name")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Menu icon:")

            Kirigami.Icon {
                source: root.cfg_groupIcon || "applications-all"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            PlasmaComponents.Button {
                text: i18n("Choose…")
                onClicked: root.chooseIcon("", false)
            }

            PlasmaComponents.Button {
                text: i18n("Image…")
                onClicked: root.chooseIcon("", true)
            }

            PlasmaComponents.Button {
                text: i18n("Reset")
                enabled: root.cfg_groupIcon !== root.cfg_groupIconDefault
                onClicked: root.cfg_groupIcon = root.cfg_groupIconDefault
            }
        }
        PlasmaComponents.CheckBox {
            id: iconsOnlyCheck
            Kirigami.FormData.label: i18n("Menu display:")
            text: root.cfg_menuSource === "folder"
                ? i18n("Icons only (unavailable for Live Folder)")
                : i18n("Icons only (show names on hover)")
            enabled: root.cfg_menuSource !== "folder"
        }

        PlasmaComponents.SpinBox {
            id: hoverDelayField
            Kirigami.FormData.label: i18n("Hover delay (ms):")
            from: 0
            to: 2000
            stepSize: 25
            value: 250
            editable: true
            // Commit valid typed numbers immediately so Apply sees the new value.
            live: true
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            wrapMode: Text.WordWrap
            text: i18n("Applies to the panel button and all subfolders. Set to 0 for immediate opening; the default is 250 ms.")
        }

        PlasmaComponents.SpinBox {
            id: menuIconSizeField
            live: true
            Kirigami.FormData.label: i18n("Menu icon size (px):")
            from: 16
            to: 64
            value: 22
            editable: true
        }
    }

    RowLayout {
        visible: root.cfg_menuSource === "categories" || root.cfg_menuSource === "activity"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.largeSpacing
        QQC2.Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 4
            Layout.minimumWidth: 0
            ColumnLayout {
                anchors.fill: parent
                PlasmaComponents.Label {
                    text: i18n("Categories (%1 selected)", root.cfg_applicationCategories.length)
                    font.bold: true
                }
                PlasmaComponents.TextField {
                    id: categorySearch
                    Layout.fillWidth: true
                    placeholderText: i18n("Filter categories…")
                    clearButtonShown: true
                    Keys.onReturnPressed: event => { event.accepted = true }
                    Keys.onEnterPressed: event => { event.accepted = true }
                }
                PlasmaComponents.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    ListView {
                        clip: true
                        model: root.availableCategories.filter(value => value.toLowerCase().includes(categorySearch.text.toLowerCase()))
                        delegate: PlasmaComponents.CheckBox {
                            required property string modelData
                            width: ListView.view.width
                            text: modelData
                            checked: (root.cfg_applicationCategories || []).indexOf(modelData) !== -1
                            onClicked: root.toggleCategory(modelData, checked)
                        }
                    }
                }
            }
        }
        QQC2.Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 5
            Layout.minimumWidth: 0
            ColumnLayout {
                anchors.fill: parent
                PlasmaComponents.Label {
                    text: root.cfg_menuSource === "activity" ? i18n("Category filter") : i18n("Matching applications (%1)", root.categoryMatches.length)
                    font.bold: true
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.cfg_menuSource === "activity"
                        ? i18n("Leave categories unchecked for all applications. Usage ranking refreshes when the stack opens. KDE Activities tracking must be enabled; TLBStacks does not change tracking settings.")
                        : i18n("Include applications in any selected category. Category names come from installed applications.")
                    wrapMode: Text.WordWrap
                }
                PlasmaComponents.Label {
                    visible: root.categoryMatches.length === 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: root.cfg_applicationCategories.length === 0
                        ? (root.cfg_menuSource === "activity" ? i18n("All applications are eligible. Open the stack to see usage-ranked results.") : i18n("Select at least one category.")) : i18n("No installed applications match these categories.")
                }
                PlasmaComponents.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    ListView {
                        clip: true
                        model: root.categoryMatches
                        delegate: PlasmaComponents.ItemDelegate {
                            required property var modelData
                            width: ListView.view.width
                            text: modelData.name
                            icon.name: modelData.icon
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        visible: root.cfg_menuSource === "applications"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.largeSpacing
        QQC2.Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 4
            Layout.minimumWidth: 0
            ColumnLayout {
                anchors.fill: parent
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: i18n("In this group (%1)", root.cfg_applications.length)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "insert-horizontal-rule"
                        Accessible.name: i18n("Insert separator")
                        onClicked: root.insertSeparator()
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "go-up"
                        Accessible.name: i18n("Move selected item up")
                        enabled: selectedApplications.currentIndex > 0
                        onClicked: root.moveApplication(selectedApplications.currentIndex, -1)
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "go-down"
                        Accessible.name: i18n("Move selected item down")
                        enabled: selectedApplications.currentIndex >= 0 && selectedApplications.currentIndex < selectedApplications.count - 1
                        onClicked: root.moveApplication(selectedApplications.currentIndex, 1)
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "list-remove"
                        Accessible.name: i18n("Remove selected item")
                        enabled: selectedApplications.currentIndex >= 0 && selectedApplications.currentIndex < selectedApplications.count
                        onClicked: {
                            const index = selectedApplications.currentIndex
                            root.setApplicationSelected(root.cfg_applications[index], false)
                            selectedApplications.currentIndex = Math.min(index, root.cfg_applications.length - 1)
                        }
                    }
                }
                PlasmaComponents.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    ListView {
                        id: selectedApplications
                        clip: true
                        model: root.cfg_applications
                        currentIndex: -1
                        delegate: PlasmaComponents.ItemDelegate {
                            id: selectedRow
                            required property int index
                            required property string modelData
                            readonly property bool isSeparator: root.isSeparator(modelData)
                            width: ListView.view.width
                            highlighted: ListView.isCurrentItem
                            readonly property string applicationName: {
                                if (isSeparator) return ""
                                const revision = root.catalogRevision
                                return launcher.name(modelData)
                            }
                            Accessible.name: isSeparator ? i18n("Separator")
                                : applicationName || modelData
                            onClicked: { selectedApplications.currentIndex = index; forceActiveFocus() }
                            contentItem: RowLayout {
                                ApplicationIcon {
                                    source: appIconButton.effectiveIcon
                                    visible: !selectedRow.isSeparator
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    visible: !selectedRow.isSeparator
                                    text: selectedRow.applicationName || selectedRow.modelData
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: selectedRow.isSeparator
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                    Layout.preferredHeight: 1
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                QQC2.TextField {
                                    visible: selectedRow.isSeparator
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: selectedRow.isSeparator ? root.separatorLabel(selectedRow.modelData) : ""
                                    placeholderText: i18n("Separator label (optional)")
                                    maximumLength: 64
                                    horizontalAlignment: Text.AlignHCenter
                                    Accessible.name: i18n("Separator label")
                                    onActiveFocusChanged: if (activeFocus) selectedApplications.currentIndex = selectedRow.index
                                    onEditingFinished: root.setSeparatorLabel(selectedRow.index, text)
                                }
                                Rectangle {
                                    visible: selectedRow.isSeparator
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                    Layout.preferredHeight: 1
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                PlasmaComponents.Button {
                                    id: appIconButton
                                    visible: !selectedRow.isSeparator
                                    readonly property string effectiveIcon: {
                                        if (selectedRow.isSeparator) return ""
                                        const revision = root.catalogRevision
                                        return IconOverrides.get(root.applicationIcons, selectedRow.modelData) ||
                                            launcher.icon(selectedRow.modelData) || "application-x-executable"
                                    }
                                    display: QQC2.AbstractButton.IconOnly
                                    icon.name: "document-edit"
                                    Accessible.name: i18n("Change icon for %1", selectedRow.applicationName || selectedRow.modelData)
                                    onClicked: { selectedApplications.currentIndex = selectedRow.index; appIconMenu.open() }

                                    PlasmaComponents.ToolTip {
                                        text: i18n("Change icon")
                                    }

                                    PlasmaComponents.Menu {
                                        id: appIconMenu
                                        PlasmaComponents.MenuItem {
                                            text: i18n("Choose icon…")
                                            onTriggered: root.chooseIcon(selectedRow.modelData, false)
                                        }
                                        PlasmaComponents.MenuItem {
                                            text: i18n("Choose image…")
                                            onTriggered: root.chooseIcon(selectedRow.modelData, true)
                                        }
                                        PlasmaComponents.MenuItem {
                                            text: i18n("Reset icon")
                                            enabled: IconOverrides.get(root.applicationIcons, selectedRow.modelData).length > 0
                                            onTriggered: root.setCustomIcon(selectedRow.modelData, "")
                                        }
                                    }
                                }

                            }
                        }
                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: selectedApplications.count === 0
                            text: i18n("Add applications from the list on the right.")
                        }
                    }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Select a row to reorder or remove it. Use its edit button to customize the icon.")
                    opacity: 0.7
                }
            }
        }
        QQC2.Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 5
            Layout.minimumWidth: 0
            ColumnLayout {
                anchors.fill: parent
                PlasmaComponents.Label { text: i18n("Add applications"); font.bold: true }
                PlasmaComponents.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18n("Search applications…")
                    clearButtonShown: true
                    Keys.onReturnPressed: event => { event.accepted = true }
                    Keys.onEnterPressed: event => { event.accepted = true }
                }
                PlasmaComponents.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    ListView {
                        id: applicationList
                        clip: true
                        model: applicationsModel
                        delegate: RowLayout {
                            id: applicationDelegate
                            required property string desktopId
                            required property string applicationName
                            required property string applicationIcon
                            width: ListView.view.width
                            visible: (searchField.text.length === 0 || applicationName.toLowerCase().includes(searchField.text.toLowerCase()))
                                && root.cfg_applications.indexOf(desktopId) === -1
                            height: visible ? implicitHeight : 0
                            Kirigami.Icon {
                                source: applicationDelegate.applicationIcon || "application-x-executable"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: applicationDelegate.applicationName
                                elide: Text.ElideRight
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: "list-add"
                                Accessible.name: i18n("Add %1", applicationDelegate.applicationName)
                                onClicked: root.setApplicationSelected(applicationDelegate.desktopId, true)
                            }
                        }
                    }
                }
            }
        }
    }
}

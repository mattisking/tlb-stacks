pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as IconThemes
import org.kde.plasma.components as PlasmaComponents
import "IconOverrides.js" as IconOverrides
import "ApplicationCategories.js" as ApplicationCategories
import com.mattphilmon.tlbstacks

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
    property string folderError: ""
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

    // Settings-fallback policy: `??` wherever a falsy value is legitimate
    // stored data (hoverDelay 0 means immediate opening; a cleared
    // folderFilters string is real input) and `||` where a falsy value must
    // fall back by design (groupIcon "" means "use the default icon";
    // menuSource "" would leave the contents pages blank) or where the
    // value is an array, which is truthy when empty, so `||` and `??`
    // agree. Text fallbacks to "" (folderUrl, groupName) are identical
    // under either operator.

    // ---- contents pages (data out: partial changes only, host persists)
    function memberName(desktopId) {
        const app = catalog.find(entry => entry.desktopId === desktopId)
        return app ? app.name : i18n("%1 (unavailable)", desktopId)
    }
    function memberIcon(desktopId) {
        return IconOverrides.get(applicationIcons, desktopId) ||
            (catalog.find(entry => entry.desktopId === desktopId) || {}).icon ||
            "application-x-executable"
    }
    function emitApplications(next) { settingsEdited({applications: next}) }
    function addMember(desktopId) {
        if (!desktopId || (settings.applications || []).includes(desktopId)
            || (settings.applications || []).length >= 2000) return
        emitApplications((settings.applications || []).concat([desktopId]))
    }
    function removeMember(index) {
        const next = (settings.applications || []).slice()
        if (index < 0 || index >= next.length) return
        next.splice(index, 1)
        emitApplications(next)
    }
    function moveMember(index, delta) {
        const apps = settings.applications || []
        const target = index + delta
        if (index < 0 || index >= apps.length || target < 0 || target >= apps.length) return
        const next = apps.slice()
        next.splice(target, 0, next.splice(index, 1)[0])
        emitApplications(next)
    }
    function addSeparator() { emitApplications(StackMembers.appendSeparator(settings.applications || [])) }
    function renameSeparator(id, label) { emitApplications(StackMembers.renameSeparator(settings.applications || [], id, label)) }
    function toggleCategory(name, on) {
        const next = (settings.applicationCategories || []).filter(value => value !== name)
        if (on) next.push(name)
        settingsEdited({applicationCategories: next})
    }
    function matchesCount() {
        return ApplicationCategories.matching(catalog, settings.applicationCategories || []).length
    }
    // Preview model for the category-filter pages: what the selection would
    // actually pull in. The panel renders the real results; this is the
    // editor's read-only preview of them.
    readonly property var categoryMatches: ApplicationCategories.matching(catalog, settings.applicationCategories || [])

    // ---- icon flow (Choose… / Image… / Reset, per existing single-host behavior)
    property string iconTarget: ""   // "" = the stack icon; otherwise a desktopId
    property var iconPending: null
    property string iconError: ""    // last failed icon operation's message

    function chooseIcon(target, fromFile) {
        iconError = ""
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
    // Result intake split out of the Connections handler so tests can drive
    // the failure path headlessly: profile.py raises for bad or oversized
    // images and answers {ok: false, error}, which previously vanished.
    function handleIconResult(requestId, result) {
        if (!iconPending || iconPending.id !== requestId) return
        const target = iconPending.target
        iconPending = null
        if (result.ok) {
            iconError = ""
            applyIconResult(target, result.icon)
        } else {
            iconError = result.error || i18n("The icon could not be applied.")
        }
    }
    Connections {
        target: root.launcher
        function onProfileFinished(requestId, result) { root.handleIconResult(requestId, result) }
    }
    IconThemes.IconDialog { id: stackIconDialog; onIconNameChanged: if (iconName.length > 0) root.setCustomIcon(root.iconTarget, iconName) }
    Dialogs.FileDialog {
        id: iconFileDialog
        objectName: "iconFileDialog"
        title: i18n("Choose an icon image")
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: [i18n("Icon images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.ico)")]
        onAccepted: {
            const url = selectedFile.toString()
            if (url.startsWith("file://"))
                root.setCustomIcon(root.iconTarget, decodeURIComponent(url.substring(7)))
        }
    }

    // Adding members goes through the shared search-on-add dialog; the live
    // folder picker rejects non-local URLs (Live Folder reads local paths).
    AppPickerDialog {
        id: appPicker
        applications: root.catalog
        onPicked: id => root.addMember(id)
    }
    Dialogs.FolderDialog {
        id: folderPicker
        title: i18n("Choose a local folder")
        onAccepted: {
            const url = selectedFolder.toString()
            if (!url.startsWith("file:///")) {
                root.folderError = i18n("Live Folder currently supports local folders only.")
            } else {
                root.folderError = ""
                root.setField("folderUrl", url)
            }
        }
    }

    // ---- matching-applications preview (shared by the category-filter pages)
    // Read-only preview of the applications the selected categories match —
    // user feedback: the selection's effect was invisible. Plain
    // ItemDelegates with icon + name and NO add/remove affordances: the
    // panel renders results, this preview must look read-only. Data comes in
    // through properties (same in/data-out pattern as CategoryChipBar) so
    // the component stays presentational. `activityMode` swaps the
    // zero-selection hint to the all-applications-eligible wording.
    component MatchingPreview: ColumnLayout {
        id: preview
        objectName: "matchingPreview"
        property bool activityMode: false
        property var matches: []
        property var selectedCategories: []
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: preview.matches.length > 0
                ? i18nc("%1 is a number of applications", "Matching applications (%1)", preview.matches.length)
                : i18n("Matching applications")
            font.bold: true
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: preview.matches.length === 0
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: preview.selectedCategories.length === 0
                ? (preview.activityMode
                    ? i18n("All applications are eligible. Open the stack to see usage-ranked results.")
                    : i18n("Select at least one category."))
                : i18n("No installed applications match these categories.")
        }
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 6
            contentWidth: availableWidth
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            ListView {
                id: matchingList
                objectName: "matchingList"
                clip: true
                model: preview.matches
                delegate: PlasmaComponents.ItemDelegate {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name
                    icon.name: modelData.icon || "application-x-executable"
                }
            }
        }
    }

    PlasmaComponents.Label {
        objectName: "iconErrorLabel"
        Layout.fillWidth: true
        visible: root.iconError.length > 0
        text: root.iconError
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Kirigami.Theme.negativeTextColor
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
                // User request: every segment is framed at all times; the
                // active one keeps its existing highlight. A transparent-fill
                // overlay adds the outline without replacing or fighting the
                // background — the active accent fill is the Plasma theme's
                // "toolbutton-pressed" frame (private/FlatButtonBackground),
                // and item children paint above background and contentItem,
                // so this 1px stroke just frames whatever the theme draws.
                // Plain Rectangles accept no mouse buttons, so clicks still
                // reach the button.
                Rectangle {
                    objectName: "kindBorder"
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: "transparent"
                    border.width: 1
                    // Text color at low opacity: a subtle frame that tracks
                    // theme contrast on both light and dark themes.
                    border.color: Kirigami.Theme.textColor
                    opacity: 0.3
                }
            }
        }
    }

    QQC2.TabBar {
        id: tabs
        objectName: "tabs"
        Layout.fillWidth: true
        QQC2.TabButton { text: i18n("Contents") }
        QQC2.TabButton { text: i18n("Appearance") }
    }

    // StackLayout is a QtQuick.Layouts type, not a QtQuick.Controls type.
    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: tabs.currentIndex

        // ---- Contents: one page per source; the kind row drives the switch
        StackLayout {
            id: contentsPages
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.kinds.findIndex(kind => kind.id === root.menuSource)

            // Selected applications: member list with separators, per-row
            // reorder/remove/icon-override, add through the shared picker.
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                    ListView {
                        id: memberList
                        objectName: "memberList"
                        clip: true
                        model: root.settings.applications || []
                        delegate: RowLayout {
                            id: memberRow
                            required property string modelData
                            required property int index
                            readonly property bool isSeparator: StackMembers.isSeparator(memberRow.modelData)
                            width: ListView.view.width
                            ApplicationIcon {
                                visible: !memberRow.isSeparator
                                source: root.memberIcon(memberRow.modelData)
                                fallbackSource: (root.catalog.find(app => app.desktopId === memberRow.modelData) || {}).icon || "application-x-executable"
                                sourceAvailable: root.launcher ? root.launcher.themeIconAvailable(source) : true
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                visible: !memberRow.isSeparator
                                text: root.memberName(memberRow.modelData)
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: memberRow.isSeparator
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                Layout.preferredHeight: 1
                                color: Kirigami.Theme.disabledTextColor
                            }
                            QQC2.TextField {
                                visible: memberRow.isSeparator
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: memberRow.isSeparator ? StackMembers.separatorLabel(memberRow.modelData) : ""
                                placeholderText: i18n("Separator label (optional)")
                                maximumLength: 64
                                horizontalAlignment: Text.AlignHCenter
                                Accessible.name: i18n("Separator label")
                                onEditingFinished: root.renameSeparator(memberRow.modelData, text)
                            }
                            Rectangle {
                                visible: memberRow.isSeparator
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                Layout.preferredHeight: 1
                                color: Kirigami.Theme.disabledTextColor
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: "go-up"
                                enabled: memberRow.index > 0
                                Accessible.name: i18n("Move up")
                                onClicked: root.moveMember(memberRow.index, -1)
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: "go-down"
                                enabled: memberRow.index < (root.settings.applications || []).length - 1
                                Accessible.name: i18n("Move down")
                                onClicked: root.moveMember(memberRow.index, 1)
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: "list-remove"
                                Accessible.name: memberRow.isSeparator ? i18n("Remove separator")
                                    : i18n("Remove %1", root.memberName(memberRow.modelData))
                                onClicked: root.removeMember(memberRow.index)
                            }
                            PlasmaComponents.ToolButton {
                                visible: !memberRow.isSeparator
                                icon.name: "preferences-desktop-icons"
                                Accessible.name: i18n("Change icon for %1", root.memberName(memberRow.modelData))
                                onClicked: iconMenu.open()

                                PlasmaComponents.ToolTip {
                                    text: i18n("Change icon")
                                }

                                PlasmaComponents.Menu {
                                    id: iconMenu
                                    PlasmaComponents.MenuItem {
                                        text: i18n("Choose icon…")
                                        onTriggered: root.chooseIcon(memberRow.modelData, false)
                                    }
                                    PlasmaComponents.MenuItem {
                                        text: i18n("Choose image…")
                                        onTriggered: root.chooseIcon(memberRow.modelData, true)
                                    }
                                    PlasmaComponents.MenuItem {
                                        text: i18n("Reset icon")
                                        enabled: IconOverrides.get(root.applicationIcons, memberRow.modelData).length > 0
                                        onTriggered: root.setCustomIcon(memberRow.modelData, "")
                                    }
                                }
                            }
                        }
                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            visible: memberList.count === 0
                            text: i18n("Add an application or a separator below.")
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Button {
                        text: i18n("Add application…")
                        icon.name: "list-add"
                        enabled: (root.settings.applications || []).length < 2000
                        onClicked: {
                            appPicker.exclude = root.settings.applications
                            appPicker.openPicker()
                        }
                    }
                    PlasmaComponents.Button {
                        text: i18n("Add separator")
                        icon.name: "list-add"
                        enabled: (root.settings.applications || []).length < 2000
                        onClicked: root.addSeparator()
                    }
                }
            }

            // Live folder: folder picker + read-only path + include patterns,
            // mirroring the group host's folder column.
            QQC2.ScrollView {
                id: folderScroll
                objectName: "folderScroll"
                contentWidth: availableWidth
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                Kirigami.FormLayout {
                    width: Math.min(folderScroll.availableWidth, Kirigami.Units.gridUnit * 36)
                    wideMode: false

                    RowLayout {
                        Kirigami.FormData.label: i18n("Folder:")
                        Layout.fillWidth: true
                        PlasmaComponents.Button {
                            text: i18n("Choose folder…")
                            onClicked: folderPicker.open()
                        }
                        PlasmaComponents.TextField {
                            objectName: "folderUrlField"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitWidth: 0
                            readOnly: true
                            text: {
                                const url = root.settings.folderUrl || ""
                                try { return url.startsWith("file:///") ? decodeURIComponent(url.substring(7)) : url }
                                catch (error) { return url }
                            }
                            placeholderText: i18n("No folder selected")
                            Accessible.name: i18n("Selected folder")
                        }
                    }
                    PlasmaComponents.TextField {
                        objectName: "folderFiltersField"
                        Kirigami.FormData.label: i18n("File patterns:")
                        Layout.fillWidth: true
                        Accessible.name: i18n("File patterns")
                        placeholderText: i18n("File patterns, for example *.pdf;*.docx")
                        // `??`: a cleared field is real stored input (the old host
                        // displayed storage verbatim); "*" is only for "missing".
                        text: root.settings.folderFilters ?? "*"
                        onTextEdited: root.setField("folderFilters", text)
                        Keys.onReturnPressed: event => { event.accepted = true }
                        Keys.onEnterPressed: event => { event.accepted = true }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: root.folderError || i18n("Separate patterns with semicolons, for example *.pdf;*.docx. Subfolders are always shown.")
                        wrapMode: Text.WordWrap
                    }
                }

            }

            // Categories: filterable chips (selected ones lead and are never
            // filtered out) with the read-only matching-applications preview
            // stacked below — both stay visible together in the tabbed
            // inspector, no interaction needed to see the selection's effect.
            QQC2.ScrollView {
                id: categoryScroll
                objectName: "categoryScroll"
                contentWidth: availableWidth
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ColumnLayout {
                    width: categoryScroll.availableWidth

                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: i18n("Match any selected category:")
                        wrapMode: Text.WordWrap
                    }
                    CategoryChipBar {
                        Layout.fillWidth: true
                        categories: ApplicationCategories.available(root.catalog, root.settings.applicationCategories)
                        // `|| []`: settings may be the editor's own empty default
                        // ({}), whose applicationCategories is undefined.
                        selected: root.settings.applicationCategories || []
                        onCategoryToggled: (name, on) => root.toggleCategory(name, on)
                    }
                    MatchingPreview {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                        matches: root.categoryMatches
                        // `|| []` per the bar's note above.
                        selectedCategories: root.settings.applicationCategories || []
                    }
                }

            }

            // Recent/frequent: usage options plus the same optional category
            // filter; ranking stays dynamic (no editable result list).
            QQC2.ScrollView {
                id: activityScroll
                objectName: "activityScroll"
                contentWidth: availableWidth
                clip: true
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                ColumnLayout {
                    width: activityScroll.availableWidth

                    spacing: Kirigami.Units.smallSpacing
                    GridLayout {
                        id: activityOptions
                        objectName: "activityOptions"
                        Layout.fillWidth: true
                        columns: activityScroll.availableWidth >= Kirigami.Units.gridUnit * 16 ? 2 : 1
                        columnSpacing: Kirigami.Units.largeSpacing
                        rowSpacing: Kirigami.Units.smallSpacing
                        PlasmaComponents.Label {
                            text: i18n("Order:")
                        }
                        PlasmaComponents.ComboBox {
                            Layout.fillWidth: true
                            Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                            Layout.alignment: Qt.AlignLeft
                            Accessible.name: i18n("Activity order")
                            model: [i18n("Most recent"), i18n("Most frequent")]
                            currentIndex: root.settings.activityOrder === "frequent" ? 1 : 0
                            onActivated: root.setField("activityOrder", currentIndex === 1 ? "frequent" : "recent")
                        }
                        PlasmaComponents.Label {
                            text: i18n("Limit:")
                        }
                        QQC2.SpinBox {
                            objectName: "activityLimitField"
                            Accessible.name: i18n("Maximum applications")
                            Layout.alignment: Qt.AlignLeft
                            from: 1; to: 50
                            value: root.settings.activityLimit ?? 10
                            onValueModified: root.setField("activityLimit", value)
                        }
                        PlasmaComponents.CheckBox {
                            Layout.columnSpan: activityOptions.columns
                            Layout.alignment: Qt.AlignLeft
                            text: i18n("Current Activity only")
                            checked: root.settings.activityCurrent ?? false
                            onToggled: root.setField("activityCurrent", checked)
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: i18n("Optional categories (none means all applications):")
                        wrapMode: Text.WordWrap
                    }
                    CategoryChipBar {
                        Layout.fillWidth: true
                        categories: ApplicationCategories.available(root.catalog, root.settings.applicationCategories)
                        // `|| []`: settings may be the editor's own empty default
                        // ({}), whose applicationCategories is undefined.
                        selected: root.settings.applicationCategories || []
                        onCategoryToggled: (name, on) => root.toggleCategory(name, on)
                    }
                    MatchingPreview {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 12
                        activityMode: true
                        matches: root.categoryMatches
                        // `|| []` per the bar's note above.
                        selectedCategories: root.settings.applicationCategories || []
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: i18n("KDE Activities tracking must be enabled; TLBStacks does not change tracking settings.")
                    }
                }            }


        }

        // ---- Appearance (Flickable so it scrolls independently of the tree)
        // Flickable is a QtQuick type, not a QtQuick.Controls type.
        Flickable {
            contentWidth: width
            contentHeight: appearanceForm.implicitHeight
            clip: true
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            Kirigami.FormLayout {
                id: appearanceForm
                width: Math.min(parent.width, Kirigami.Units.gridUnit * 36)
                wideMode: false
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
                    objectName: "iconsOnlyBox"
                    Kirigami.FormData.label: i18n("Display:")
                    text: root.menuSource === "folder" ? i18n("Icons only (unavailable for Live Folder)")
                        : i18n("Icons only (show names on hover)")
                    enabled: root.menuSource !== "folder"
                    // `??` per policy; false is the stored default either way.
                    checked: root.settings.iconsOnly ?? false
                    onToggled: root.setField("iconsOnly", checked)
                }
                QQC2.SpinBox {
                    objectName: "menuIconSizeField"
                    Kirigami.FormData.label: i18n("Icon size (px):")
                    from: 16; to: 64
                    editable: true
                    live: true
                    // `??` per policy; the schema range is 16–64.
                    value: root.settings.menuIconSize ?? 22
                    onValueChanged: if (value !== (root.settings.menuIconSize ?? 22)) root.setField("menuIconSize", value)
                }
                QQC2.SpinBox {
                    objectName: "hoverDelayField"
                    Kirigami.FormData.label: i18n("Hover delay (ms):")
                    from: 0; to: 2000; stepSize: 50
                    editable: true
                    live: true
                    // 0 is a legitimate stored value (immediate opening) —
                    // `??`, never `||` (which showed 250 for a stored 0).
                    value: root.settings.hoverDelay ?? 250
                    onValueChanged: if (value !== (root.settings.hoverDelay ?? 250)) root.setField("hoverDelay", value)
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: i18n("Applies to this stack's button and all its subfolders. Set to 0 for immediate opening; the default is 250 ms.")
                }
            }
        }
    }
}

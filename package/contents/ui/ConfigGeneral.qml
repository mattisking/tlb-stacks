import QtQuick
import QtQuick.Dialogs as Dialogs
import "IconOverrides.js" as IconOverrides
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import com.mattphilmon.tlbstacks

ColumnLayout {
    id: root
    enabled: !launcher.profileBusy
    property var pendingProfile: null
    property int catalogRevision: 0

    property string title: i18n("General")
    property string cfg_groupName: ""
    property string cfg_groupNameDefault: ""
    property string cfg_groupIcon: "applications-all"
    property string cfg_groupIconDefault: "applications-all"
    property bool cfg_iconsOnly: false
    property bool cfg_iconsOnlyDefault: false
    property int cfg_menuIconSize: 22
    property int cfg_menuIconSizeDefault: 22
    property int cfg_hoverDelay: 250
    property int cfg_hoverDelayDefault: 250
    property string cfg_customLaunchers: "{}"
    property string cfg_customLaunchersDefault: "{}"
    property string cfg_applicationIcons: "{}"
    property string cfg_applicationIconsDefault: "{}"
    readonly property var applicationIcons: IconOverrides.parse(cfg_applicationIcons)
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
    property string cfg_folderHeightCache: "{}"
    property string cfg_folderHeightCacheDefault: "{}"
    property string cfg_folderUrl: ""
    property string cfg_folderUrlDefault: ""
    property string cfg_folderFilters: "*"
    property string cfg_folderFiltersDefault: "*"
    property string profileMessage: ""
    property var missingApplications: []
    // Plasma supplies these from main.xml and commits edits on Apply/OK.
    property var cfg_applications: []
    property var cfg_applicationsDefault: []

    // The settings object the shared editor edits; re-synthesized whenever
    // any cfg_* it reads changes, so persisted edits flow back into the
    // editor through the settings binding.
    readonly property var stackSettings: ({
        groupName: cfg_groupName, groupIcon: cfg_groupIcon, iconsOnly: cfg_iconsOnly,
        menuIconSize: cfg_menuIconSize, hoverDelay: cfg_hoverDelay,
        applications: Array.from(cfg_applications || []),
        customLaunchers: StackMembers.parseCustomLaunchers(cfg_customLaunchers),
        applicationIcons: IconOverrides.parse(cfg_applicationIcons),
        menuSource: cfg_menuSource, activityOrder: cfg_activityOrder,
        activityLimit: cfg_activityLimit, activityCurrent: cfg_activityCurrent,
        applicationCategories: Array.from(cfg_applicationCategories || []),
        folderUrl: cfg_folderUrl, folderFilters: cfg_folderFilters
    })

    // Partial {field: value} changes from the shared editor, persisted into
    // the cfg_* storage Plasma commits on Apply/OK.
    function applySettingsChanges(changes) {
        if ("groupName" in changes) cfg_groupName = changes.groupName
        if ("groupIcon" in changes) cfg_groupIcon = changes.groupIcon
        if ("iconsOnly" in changes) cfg_iconsOnly = changes.iconsOnly
        if ("menuIconSize" in changes) cfg_menuIconSize = changes.menuIconSize
        if ("hoverDelay" in changes) cfg_hoverDelay = changes.hoverDelay
        if ("applications" in changes) cfg_applications = changes.applications
        if ("customLaunchers" in changes) cfg_customLaunchers = JSON.stringify(changes.customLaunchers)
        if ("applicationIcons" in changes) cfg_applicationIcons = JSON.stringify(changes.applicationIcons)
        if ("menuSource" in changes) cfg_menuSource = changes.menuSource
        if ("activityOrder" in changes) cfg_activityOrder = changes.activityOrder
        if ("activityLimit" in changes) cfg_activityLimit = changes.activityLimit
        if ("activityCurrent" in changes) cfg_activityCurrent = changes.activityCurrent
        if ("applicationCategories" in changes) cfg_applicationCategories = changes.applicationCategories
        if ("folderUrl" in changes) cfg_folderUrl = changes.folderUrl
        if ("folderFilters" in changes) cfg_folderFilters = changes.folderFilters
    }

    Launcher {
        id: launcher
        onApplicationsChanged: {
            root.catalogRevision++
            root.loadApplications()
            root.refreshMissingApplications()
        }
        onProfileFinished: (requestId, result) => root.finishProfile(requestId, result)
    }

    function profileSettings() {
        return {
            groupName: root.cfg_groupName,
            groupIcon: root.cfg_groupIcon,
            iconsOnly: root.cfg_iconsOnly,
            menuIconSize: root.cfg_menuIconSize,
            hoverDelay: root.cfg_hoverDelay,
            applications: Array.from(root.cfg_applications),
            customLaunchers: StackMembers.parseCustomLaunchers(root.cfg_customLaunchers),
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
        if (pending.action === "export") {
            root.profileMessage = i18n("Menu exported with its custom images.")
        } else if (pending.action === "import") {
            const settings = result.settings
            root.cfg_groupName = settings.groupName
            root.cfg_groupIcon = settings.groupIcon
            root.cfg_iconsOnly = settings.iconsOnly
            root.cfg_menuIconSize = settings.menuIconSize
            root.cfg_hoverDelay = settings.hoverDelay
            root.cfg_customLaunchers = JSON.stringify(settings.customLaunchers || {})
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
            if (result.folderMissing)
                root.profileMessage += "\n" + i18n("The imported folder is unavailable on this machine. Choose its location before applying.")
        }
    }

    function refreshMissingApplications() {
        const commands = StackMembers.parseCustomLaunchers(root.cfg_customLaunchers)
        root.missingApplications = Array.from(root.cfg_applications || [])
            .map(id => (commands[id] || {}).desktopId || id)
            .filter(id => !id.startsWith("tlbstacks-command:") && !StackMembers.isSeparator(id) && !launcher.exists(id))
    }

    onCfg_applicationsChanged: refreshMissingApplications()
    onCfg_customLaunchersChanged: refreshMissingApplications()

    ListModel {
        id: applicationsModel
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

    StackSettingsEditor {
        id: stackEditor
        Layout.fillWidth: true
        Layout.fillHeight: true
        settings: root.stackSettings
        catalog: root.categoryApplications
        launcher: launcher
        stackIconDefault: root.cfg_groupIconDefault
        onSettingsEdited: (changes) => root.applySettingsChanges(changes)
    }
}

import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

Rectangle {
    width: 760; height: 560
    StackSettingsEditor {
        id: editor
        anchors.fill: parent
        settings: ({
            menuSource: "applications", groupName: "Dev", groupIcon: "applications-development",
            applications: ["code.desktop", "tlbstacks-separator:1"],
            applicationIcons: {}, iconsOnly: false, menuIconSize: 22, hoverDelay: 250,
            applicationCategories: [], activityOrder: "recent", activityLimit: 10,
            activityCurrent: false, folderUrl: "", folderFilters: "*" })
        // The harness plays the host: persist emitted partial changes back
        // into the settings the editor reads, exactly like the real hosts
        // (the group host's updateStack / the single host's applySettingsChanges,
        // fed back through the settings binding). The cumulative Contents tests
        // below need that loop to observe prior operations' state.
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
        catalog: [
            {desktopId: "code.desktop", name: "Visual Studio Code", icon: "code"},
            {desktopId: "dolphin.desktop", name: "Dolphin", icon: "system-file-manager"},
            {desktopId: "gone.desktop", name: "Gone", icon: "gone"}
        ]
    }
    SignalSpy { id: spy; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorShell"
        when: windowShown
        function init() { spy.clear() }

        function test_kind_segments_emit_menuSource() {
            const folder = findChild(editor, "kind-folder")
            folder.clicked()
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], {menuSource: "folder"})
        }
        function test_appearance_fields_emit_partial_changes() {
            editor.setField("groupName", "Development")
            compare(spy.signalArguments[0][0], {groupName: "Development"})
            editor.setField("iconsOnly", true)
            compare(spy.signalArguments[1][0], {iconsOnly: true})
            editor.setField("menuIconSize", 32)
            compare(spy.signalArguments[2][0], {menuIconSize: 32})
            editor.setField("hoverDelay", 400)
            compare(spy.signalArguments[3][0], {hoverDelay: 400})
        }
        function test_icon_result_applies_to_stack_or_member() {
            editor.applyIconResult("", "custom-icon")
            compare(spy.signalArguments[0][0].groupIcon, "custom-icon")
            editor.applyIconResult("code.desktop", "/images/code.png")
            compare(spy.signalArguments[1][0].applicationIcons["code.desktop"], "/images/code.png")
            editor.applyIconResult("code.desktop", "")
            compare(spy.signalArguments[2][0].applicationIcons["code.desktop"], undefined)
        }
        function test_icon_reset_uses_default() {
            editor.applyIconResult("", "")
            compare(spy.signalArguments[0][0].groupIcon, "applications-all")
        }
    }

    SignalSpy { id: spy2; target: editor; signalName: "settingsEdited" }
    TestCase {
        name: "StackSettingsEditorContents"
        when: windowShown
        function init() { spy2.clear() }

        // qmltestrunner executes test functions in alphabetical order, not
        // declaration order; the numeric prefixes keep the narrative order
        // the expectations are written against (each test builds on the
        // persisted state the previous one left in `editor.settings`).
        function test_01_member_add_rejects_duplicates() {
            editor.addMember("code.desktop")
            compare(spy2.count, 0)   // already a member
            editor.addMember("dolphin.desktop")
            const apps = spy2.signalArguments[0][0].applications
            compare(apps, ["code.desktop", "tlbstacks-separator:1", "dolphin.desktop"])
        }
        function test_02_member_move_remove_and_separator_rename() {
            editor.moveMember(2, -1)   // dolphin above separator
            compare(spy2.signalArguments[0][0].applications,
                ["code.desktop", "dolphin.desktop", "tlbstacks-separator:1"])
            editor.moveMember(0, -5)   // out of range: no-op (emits nothing)
            editor.removeMember(0)
            compare(spy2.signalArguments[1][0].applications, ["dolphin.desktop", "tlbstacks-separator:1"])
            editor.renameSeparator("tlbstacks-separator:1", "IDEs : Tools")
            compare(spy2.signalArguments[2][0].applications, ["dolphin.desktop", "tlbstacks-separator:1:IDEs : Tools"])
        }
        function test_03_add_separator_finds_free_number() {
            editor.addSeparator()
            compare(spy2.signalArguments[0][0].applications[2], "tlbstacks-separator:2")
        }
        function test_04_unavailable_member_names_fall_back() {
            compare(editor.memberName("gone.desktop"), "Gone")
            const fallback = String(editor.memberName("not-installed.desktop"))
            verify(fallback.indexOf("not-installed.desktop") >= 0)   // id stays visible
            verify(fallback.length > "not-installed.desktop".length) // wrapped in fallback text
        }
        function test_05_category_toggle_emits_next_array() {
            editor.setKind("categories")
            editor.toggleCategory("Development", true)
            compare(spy2.signalArguments[1][0].applicationCategories, ["Development"])
            editor.toggleCategory("Network", true)
            compare(spy2.signalArguments[2][0].applicationCategories, ["Development", "Network"])
            editor.toggleCategory("Development", false)
            compare(spy2.signalArguments[3][0].applicationCategories, ["Network"])
        }
        function test_06_folder_and_activity_fields() {
            editor.setField("folderUrl", "file:///home/matt/Documents")
            compare(spy2.signalArguments[0][0].folderUrl, "file:///home/matt/Documents")
            editor.setField("folderFilters", "*.pdf;*.docx")
            compare(spy2.signalArguments[1][0].folderFilters, "*.pdf;*.docx")
            editor.setField("activityOrder", "frequent")
            compare(spy2.signalArguments[2][0].activityOrder, "frequent")
            editor.setField("activityLimit", 20)
            compare(spy2.signalArguments[3][0].activityLimit, 20)
            editor.setField("activityCurrent", true)
            compare(spy2.signalArguments[4][0].activityCurrent, true)
        }
    }
}

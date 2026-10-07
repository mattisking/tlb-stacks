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
}

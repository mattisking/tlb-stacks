import QtQuick
import QtTest
import com.mattphilmon.tlbstacks

TestCase {
    name: "StackMemberReorder"
    when: windowShown
    visible: true
    width: 760; height: 560
    StackSettingsEditor {
        id: editor
        width: 760; height: 560
        onSettingsEdited: changes => settings = Object.assign({}, settings, changes)
    }
    SignalSpy { id: edits; target: editor; signalName: "settingsEdited" }
    readonly property string separator: "tlbstacks-separator:1"
    function init() {
        editor.settings = {menuSource: "applications", applications: ["first.desktop", separator, "last.desktop"],
            applicationIcons: {"first.desktop": "custom-icon"}}
        wait(30)
        findChild(editor, "memberList").positionViewAtBeginning()
        editor.activeMemberId = ""
        edits.clear()
    }
    function handle(index) {
        return findChild(findChild(editor, "memberList").itemAtIndex(index), "reorder-member-" + editor.settings.applications[index])
    }
    function test_arrows_follow_clicked_and_keyboard_focused_row() {
        const list = findChild(editor, "memberList")
        let first = list.itemAtIndex(0)
        let up = findChild(first, "member-up-first.desktop")
        let down = findChild(first, "member-down-first.desktop")
        verify(!up.visible && !down.visible)
        const downX = down.mapToItem(editor, 0, 0).x
        mouseClick(first, 120, first.height / 2)
        verify(up.visible && down.visible)
        verify(!up.enabled && down.enabled)
        compare(down.mapToItem(editor, 0, 0).x, downX)
        list.itemAtIndex(2).forceActiveFocus()
        verify(!down.visible)
        verify(findChild(list.itemAtIndex(2), "member-up-last.desktop").visible)
        first.forceActiveFocus()
        keyClick(Qt.Key_Tab)
        verify(down.activeFocus)
        keyClick(Qt.Key_Space)
        compare(editor.settings.applications[1], "first.desktop")
        wait(30)
        compare(editor.activeMemberId, "first.desktop")
        verify(findChild(list.itemAtIndex(1), "member-up-first.desktop").visible)
    }
    function test_custom_launcher_create_edit_remove() {
        editor.editCustomLauncher("")
        const dialog = findChild(editor, "customLauncherDialog")
        verify(dialog.visible)
        dialog.reject()
        verify(editor.saveCustomLauncher("", "One", "/usr/bin/echo", "'two words' --flag"))
        verify(editor.saveCustomLauncher("", "Two", "/usr/bin/echo", "different"))
        const ids = Object.keys(editor.settings.customLaunchers)
        compare(ids.length, 2)
        verify(ids[0] !== ids[1])
        compare(editor.memberName(ids[0]), "One")
        compare(editor.settings.customLaunchers[ids[0]].arguments, ["two words", "--flag"])
        verify(editor.saveCustomLauncher(ids[0], "Edited", "/usr/bin/echo", ""))
        compare(editor.memberName(ids[0]), "Edited")
        verify(!editor.saveCustomLauncher("", "Bad", "relative", ""))
        verify(!editor.saveCustomLauncher("", "Bad", "/bin/echo", "'unfinished"))
        editor.removeMember(editor.settings.applications.indexOf(ids[0]))
        verify(!editor.settings.customLaunchers[ids[0]])
        verify(editor.settings.customLaunchers[ids[1]])
    }
    function test_drag_application_past_separator() {
        const first = handle(0), last = handle(2)
        const target = last.mapToItem(first, 12, last.height - 2)
        mousePress(first, 12, first.height / 2)
        mouseMove(first, target.x, target.y, 30)
        compare(edits.count, 0)
        mouseRelease(first, target.x, target.y)
        compare(edits.count, 1)
        compare(editor.settings.applications, [separator, "last.desktop", "first.desktop"])
        compare(editor.settings.applicationIcons["first.desktop"], "custom-icon")
    }
    function test_drag_separator_to_top() {
        const source = handle(1), first = handle(0)
        const target = first.mapToItem(source, 12, 2)
        mousePress(source, 12, source.height / 2)
        mouseMove(source, target.x, target.y, 30)
        mouseRelease(source, target.x, target.y)
        compare(editor.settings.applications, [separator, "first.desktop", "last.desktop"])
    }
    function test_cancel_outside_and_escape() {
        let source = handle(0)
        mousePress(source, 12, 10)
        mouseMove(source, -30, 80, 30)
        mouseRelease(source, -30, 80)
        compare(edits.count, 0)
        source = handle(0)
        mousePress(source, 12, 10)
        mouseMove(source, 12, 80, 30)
        verify(findChild(editor, "memberReorder").active)
        keyClick(Qt.Key_Escape)
        mouseRelease(source, 12, 80)
        compare(edits.count, 0)
    }
    function test_settings_switch_cancels_gesture() {
        const controller = findChild(editor, "memberReorder")
        controller.draggingId = "first.desktop"
        controller.boundary = 3
        editor.settings = Object.assign({}, editor.settings, {groupName: "Other stack"})
        verify(!controller.active)
        controller.finish()
        compare(edits.count, 0)
    }
    function test_invalid_and_adjacent_moves_do_not_emit() {
        editor.reorderMember("missing.desktop", 0)
        editor.reorderMember("first.desktop", -1)
        editor.reorderMember("first.desktop", 1)
        compare(edits.count, 0)
        editor.settings = Object.assign({}, editor.settings, {menuSource: "categories"})
        editor.reorderMember("first.desktop", 3)
        compare(edits.count, 0)
    }
}
